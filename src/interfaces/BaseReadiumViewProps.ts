import type { ViewStyle } from 'react-native';

import type { Settings } from './Settings';
import type { Link } from './Link';
import type { Locator } from './Locator';
import type { File } from './File';
import type { Highlight } from './Highlight';

export type BaseReadiumViewProps = {
  file: File;
  location?: Locator | Link;
  settings?: Partial<Settings>;
  highlights?: Highlight[];
  style?: ViewStyle;
  onLocationChange?: (locator: Locator) => void;
  onTableOfContents?: (toc: Link[] | null) => void;
  onTranslate?: (locator: Locator) => void;
  onShowHighlight?: (highlight: Highlight) => void;
  onDeleteHighlight?: (highlight: Highlight) => void;
  ref?: any;
  height?: number;
  width?: number;
};
