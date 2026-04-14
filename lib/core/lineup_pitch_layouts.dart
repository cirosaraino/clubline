const Map<String, List<List<String>>> kFormationPitchRows = {
  '3-4-3 IN LINEA': [
    ['DCS', 'DC', 'DCD'],
    ['ES', 'CCS', 'CCD', 'ED'],
    ['AS', 'ATT', 'AD'],
  ],
  '3-4-1-2': [
    ['DCS', 'DC', 'DCD'],
    ['ES', 'CCS', 'CCD', 'ED'],
    ['COC'],
    ['ATTS', 'ATTD'],
  ],
  '3-4-2-1': [
    ['DCS', 'DC', 'DCD'],
    ['ES', 'CCS', 'CCD', 'ED'],
    ['COCS', 'COCD'],
    ['ATT'],
  ],
  '3-1-4-2': [
    ['DCS', 'DC', 'DCD'],
    ['CDC'],
    ['ES', 'CCS', 'CCD', 'ED'],
    ['ATTS', 'ATTD'],
  ],
  '3-5-2': [
    ['DCS', 'DC', 'DCD'],
    ['ES', 'CDCS', 'COC', 'CDCD', 'ED'],
    ['ATTS', 'ATTD'],
  ],
  '4-3-3 OFFENSIVO': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CCS', 'CCD'],
    ['COC'],
    ['AS', 'ATT', 'AD'],
  ],
  '4-3-3 IN LINEA': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CCS', 'CC', 'CCD'],
    ['AS', 'ATT', 'AD'],
  ],
  '4-3-1-2': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CCS', 'CC', 'CCD'],
    ['COC'],
    ['ATTS', 'ATTD'],
  ],
  '4-3-2-1': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CCS', 'CC', 'CCD'],
    ['COCS', 'COCD'],
    ['ATT'],
  ],
  '4-5-1': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['ES', 'COCS', 'CC', 'COCD', 'ED'],
    ['ATT'],
  ],
  '4-3-3 CONTENIMENTO': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDC'],
    ['CCS', 'CCD'],
    ['AS', 'ATT', 'AD'],
  ],
  '4-5-1 IN LINEA': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['ES', 'CCS', 'CC', 'CCD', 'ED'],
    ['ATT'],
  ],
  '4-4-2 IN LINEA': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['ES', 'CCS', 'CCD', 'ED'],
    ['ATTS', 'ATTD'],
  ],
  '4-4-1-1 AVANZATO': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['ES', 'CCS', 'CCD', 'ED'],
    ['COC'],
    ['ATT'],
  ],
  '4-1-2-1-2 LARGO': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDC'],
    ['ES', 'ED'],
    ['COC'],
    ['ATTS', 'ATTD'],
  ],
  '4-1-2-1-2 STRETTO': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDC'],
    ['CCS', 'CCD'],
    ['COC'],
    ['ATTS', 'ATTD'],
  ],
  '4-2-2-2': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDCS', 'CDCD'],
    ['COCS', 'COCD'],
    ['ATTS', 'ATTD'],
  ],
  '4-3-3 DIFENSIVO': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDCS', 'CDCD'],
    ['CC'],
    ['AS', 'ATT', 'AD'],
  ],
  '4-4-2 CONTENIMENTO': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['ES', 'CDCS', 'CDCD', 'ED'],
    ['ATTS', 'ATTD'],
  ],
  '4-2-4': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CCS', 'CCD'],
    ['AS', 'ATTS', 'ATTD', 'AD'],
  ],
  '4-1-3-2': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDC'],
    ['ES', 'CC', 'ED'],
    ['ATTS', 'ATTD'],
  ],
  '4-1-4-1': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDC'],
    ['ES', 'CCS', 'CCD', 'ED'],
    ['ATT'],
  ],
  '4-2-1-3': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDCS', 'CDCD'],
    ['COC'],
    ['AS', 'ATTS', 'AD'],
  ],
  '4-2-3-1 STRETTO': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDCS', 'CDCD'],
    ['COCS', 'COC', 'COCD'],
    ['ATT'],
  ],
  '4-2-3-1 LARGO': [
    ['TS', 'DCS', 'DCD', 'TD'],
    ['CDCS', 'CDCD'],
    ['ES', 'COC', 'ED'],
    ['ATT'],
  ],
  '5-2-3': [
    ['TS', 'DCS', 'DC', 'DCD', 'TD'],
    ['CCS', 'CCD'],
    ['AS', 'ATT', 'AD'],
  ],
  '5-2-1-2': [
    ['TS', 'DCS', 'DC', 'DCD', 'TD'],
    ['CCS', 'CCD'],
    ['COC'],
    ['ATTS', 'ATTD'],
  ],
  '5-4-1 IN LINEA': [
    ['TS', 'DCS', 'DC', 'DCD', 'TD'],
    ['ES', 'CCS', 'CCD', 'ED'],
    ['ATT'],
  ],
  '5-3-2': [
    ['TS', 'DCS', 'DC', 'DCD', 'TD'],
    ['CCS', 'CDC', 'CCD'],
    ['ATTS', 'ATTD'],
  ],
};

List<List<String>> lineupPitchRowsFor(String module) {
  return kFormationPitchRows[module]
          ?.map((row) => List<String>.from(row))
          .toList() ??
      const [];
}

String preferredRoleForPositionCode(String positionCode) {
  if (positionCode == 'POR') return 'POR';
  if (positionCode == 'TS') return 'TS';
  if (positionCode == 'TD') return 'TD';
  if (positionCode == 'ES') return 'ES';
  if (positionCode == 'ED') return 'ED';
  if (positionCode == 'AS') return 'AS';
  if (positionCode == 'AD') return 'AD';
  if (positionCode.startsWith('COC')) return 'COC';
  if (positionCode.startsWith('CDC')) return 'CDC';
  if (positionCode.startsWith('CC')) return 'CC';
  if (positionCode.startsWith('ATT')) return 'ATT';
  if (positionCode.startsWith('DC')) return 'DC';
  return positionCode;
}
