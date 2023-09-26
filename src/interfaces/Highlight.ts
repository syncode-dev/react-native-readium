/**
 * An interface representing the Readium Highlight object.
 */
import { Locator } from './Locator';

export interface Highlight {
  id: number;
  locator: Locator;
}
