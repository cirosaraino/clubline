const List<String> kPlayerRoles = [
  'POR',
  'TS',
  'DC',
  'TD',
  'CDC',
  'CC',
  'COC',
  'ES',
  'ED',
  'AS',
  'AD',
  'ATT',
];

const List<String> kTeamRoles = [
  'player',
  'vice_captain',
  'captain',
];

const Map<String, String> kTeamRoleLabels = {
  'player': 'Giocatore',
  'vice_captain': 'Vice',
  'captain': 'Capitano',
};

final List<String> kShirtNumberOptions = [
  '00',
  for (var i = 1; i <= 99; i++) '$i',
];

const Map<String, String> kRoleCategories = {
  'POR': 'Portiere',
  'TS': 'Difensore',
  'DC': 'Difensore',
  'TD': 'Difensore',
  'CDC': 'Centrocampista',
  'CC': 'Centrocampista',
  'COC': 'Centrocampista',
  'ES': 'Centrocampista',
  'ED': 'Centrocampista',
  'AS': 'Attaccante',
  'AD': 'Attaccante',
  'ATT': 'Attaccante',
};

const List<String> kPrimaryRoleCategoryOrder = [
  'Portiere',
  'Difensore',
  'Centrocampista',
  'Attaccante',
];

const Map<String, String> kRoleCategorySectionTitles = {
  'Portiere': 'PORTIERI',
  'Difensore': 'DIFENSORI',
  'Centrocampista': 'CENTROCAMPISTI',
  'Attaccante': 'ATTACCANTI',
};

const String kUnassignedRoleSectionTitle = 'SENZA RUOLO';

const List<String> kPrimaryRoleSortOrder = [
  'POR',
  'DC',
  'TS',
  'TD',
  'CDC',
  'CC',
  'COC',
  'ES',
  'ED',
  'AS',
  'AD',
  'ATT',
];
