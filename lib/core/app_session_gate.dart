enum AppSessionGateKind {
  resolving,
  unauthenticated,
  authenticatedNeedsPlayerProfile,
  authenticatedNeedsClubSelection,
  authenticatedWithClub,
  error,
}

AppSessionGateKind resolveAppSessionGate({
  required bool isResolving,
  required bool hasResolutionError,
  required bool isAuthenticated,
  required bool hasClubMembership,
  required bool hasPlayerIdentityDraft,
  required bool hasCurrentPlayer,
  required bool needsCurrentPlayerCompletion,
}) {
  if (isResolving) {
    return AppSessionGateKind.resolving;
  }

  if (hasResolutionError) {
    return AppSessionGateKind.error;
  }

  if (!isAuthenticated) {
    return AppSessionGateKind.unauthenticated;
  }

  if (hasClubMembership) {
    if (!hasCurrentPlayer || needsCurrentPlayerCompletion) {
      return AppSessionGateKind.authenticatedNeedsPlayerProfile;
    }

    return AppSessionGateKind.authenticatedWithClub;
  }

  if (!hasPlayerIdentityDraft) {
    return AppSessionGateKind.authenticatedNeedsPlayerProfile;
  }

  return AppSessionGateKind.authenticatedNeedsClubSelection;
}
