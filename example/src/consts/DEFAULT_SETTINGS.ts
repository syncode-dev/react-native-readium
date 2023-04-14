import {
  Settings,
  Appearance,
} from 'react-native-readium';

const DEFAULT_SETTINGS = new Settings();
DEFAULT_SETTINGS.appearance = Appearance.NIGHT;
const DEFAULT_BOOKCOVER = require('../../resources/default_bookcover.jpg');
export { DEFAULT_SETTINGS, DEFAULT_BOOKCOVER };