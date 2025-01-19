import { preferences } from "@kit.ArkData";

export function getConfigPreference(): preferences.Preferences {
  return preferences.getPreferencesSync(getContext(), { name: 'config.db' });
}