{
  aioshelly,
  btsocket,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  pycryptodome,
}:

buildHomeAssistantComponent rec {
  owner = "NicoIIT";
  domain = "ble_adv";
  version = "2.2.15";

  src = fetchFromGitHub {
    owner = "NicoIIT";
    repo = "ha-ble-adv";
    tag = "v${version}";
    hash = "sha256-piAOKmXrjW/gdLMjklimLl6BgtyyWLVIQL7VsbHTgW0=";
  };

  dependencies = [
    aioshelly
    btsocket
    pycryptodome
  ];
}
