import { randomUUID } from 'node:crypto';

import type { SupabaseClient } from '@supabase/supabase-js';

import { ValidationError } from '../lib/errors';

export const CLUB_LOGO_BUCKET = 'club-assets';
export const DEFAULT_CLUB_THEME = {
  primaryColor: '#1F2937',
  accentColor: '#0F766E',
  surfaceColor: '#0F172A',
} as const;

const allowedLogoMimeTypes = new Set([
  'image/png',
  'image/jpeg',
  'image/jpg',
  'image/webp',
  'image/gif',
  'image/svg+xml',
]);
const maxLogoBytes = 5 * 1024 * 1024;

export type ClubLogoUpload = {
  mimeType: string;
  bytes: Buffer;
  extension: string;
};

export function normalizeStoredClubLogoPath(
  value: string | null | undefined,
): string | null {
  const normalized = value?.trim() ?? '';
  return normalized.length > 0 ? normalized : null;
}

export function parseLogoUpload(dataUrl: string): ClubLogoUpload {
  const normalized = dataUrl.trim();
  const match = /^data:([^;]+);base64,(.+)$/i.exec(normalized);
  if (match == null) {
    throw new ValidationError(
      'Il logo deve essere inviato come immagine base64 valida',
    );
  }

  const declaredMimeType = normalizeMimeType(match[1] ?? '');
  const encoded = match[2] ?? '';
  const bytes = Buffer.from(encoded, 'base64');
  if (bytes.length === 0 || bytes.length > maxLogoBytes) {
    throw new ValidationError('Il logo deve essere inferiore a 5 MB');
  }

  const detectedMimeType = detectLogoMimeType(bytes);
  const mimeType = detectedMimeType ?? declaredMimeType;
  if (!allowedLogoMimeTypes.has(mimeType)) {
    throw new ValidationError('Formato logo non supportato');
  }

  return {
    mimeType,
    bytes,
    extension: extensionForMimeType(mimeType),
  };
}

export async function uploadClubLogoAsset(
  db: SupabaseClient,
  clubId: string | number,
  logoDataUrl: string,
): Promise<{ publicUrl: string; storagePath: string }> {
  const parsedLogo = parseLogoUpload(logoDataUrl);
  const storagePath = `clubs/${clubId}/logo-${Date.now()}-${randomUUID()}.${parsedLogo.extension}`;
  const bucket = db.storage.from(CLUB_LOGO_BUCKET);
  const uploadResponse = await bucket.upload(storagePath, parsedLogo.bytes, {
    contentType: parsedLogo.mimeType,
    cacheControl: '3600',
    upsert: false,
  });

  if (uploadResponse.error) {
    throw uploadResponse.error;
  }

  return {
    storagePath,
    publicUrl: bucket.getPublicUrl(storagePath).data.publicUrl,
  };
}

export async function removeClubLogoAsset(
  db: SupabaseClient,
  storagePath: string | null | undefined,
): Promise<void> {
  const normalizedStoragePath = normalizeStoredClubLogoPath(storagePath);
  if (normalizedStoragePath == null) {
    return;
  }

  const response = await db.storage.from(CLUB_LOGO_BUCKET).remove([
    normalizedStoragePath,
  ]);
  if (response.error) {
    throw response.error;
  }
}

function normalizeMimeType(value: string): string {
  const normalized = value.trim().toLowerCase();
  return normalized == 'image/jpg' ? 'image/jpeg' : normalized;
}

function extensionForMimeType(mimeType: string): string {
  return mimeType === 'image/png'
    ? 'png'
    : mimeType === 'image/jpeg'
      ? 'jpg'
      : mimeType === 'image/webp'
        ? 'webp'
        : mimeType === 'image/gif'
          ? 'gif'
          : mimeType === 'image/svg+xml'
            ? 'svg'
            : 'img';
}

function detectLogoMimeType(bytes: Buffer): string | null {
  if (looksLikeSvg(bytes)) {
    return 'image/svg+xml';
  }

  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return 'image/png';
  }

  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'image/jpeg';
  }

  if (
    bytes.length >= 12 &&
    bytes.subarray(0, 4).toString('ascii') === 'RIFF' &&
    bytes.subarray(8, 12).toString('ascii') === 'WEBP'
  ) {
    return 'image/webp';
  }

  if (
    bytes.length >= 6 &&
    (bytes.subarray(0, 6).toString('ascii') === 'GIF87a' ||
      bytes.subarray(0, 6).toString('ascii') === 'GIF89a')
  ) {
    return 'image/gif';
  }

  return null;
}

function looksLikeSvg(bytes: Buffer): boolean {
  const headerLength = Math.min(bytes.length, 180);
  const header = bytes
    .subarray(0, headerLength)
    .toString('utf8')
    .trimStart()
    .toLowerCase();
  return header.startsWith('<?xml') || header.startsWith('<svg');
}
