import React, { useEffect, useState, useRef } from 'react';
import { StyleSheet, View, Text, Platform } from 'react-native';
import {
  ReadiumView,
  Settings,
} from 'react-native-readium';
import type { Link, Locator, File, Highlight } from 'react-native-readium';

import RNFS from '../utils/RNFS';
import {
  EPUB_URL,
  EPUB_PATH,
  INITIAL_LOCATION,
  DEFAULT_SETTINGS,
} from '../consts';
import { ReaderButton } from './ReaderButton';
import { TableOfContents } from './TableOfContents';
import { Settings as ReaderSettings } from './Settings';
import { CoverImageView } from './CoverImageView';

export const Reader: React.FC = () => {
  const [toc, setToc] = useState<Link[] | null>([]);
  const [file, setFile] = useState<File>();
  const [location, setLocation] = useState<Locator | Link>();
  const [settings, setSettings] = useState<Partial<Settings>>(DEFAULT_SETTINGS);
  const [highlights, setHighlights] = useState<Highlight[]>([]);
  const [highlightId, setHighlightId] = useState<number>(1);
  const ref = useRef<any>();

  useEffect(() => {
    async function run() {

      if (Platform.OS === 'web') {
        setFile({
          url: EPUB_URL,
          initialLocation: INITIAL_LOCATION,
        });
      } else {
        const exists = await RNFS.exists(EPUB_PATH);
        if (!exists) {
          console.log(`Downloading file: '${EPUB_URL}'`);
          const { promise } = RNFS.downloadFile({
            fromUrl: EPUB_URL,
            toFile: EPUB_PATH,
            background: true,
            discretionary: true,
          });

          // wait for the download to complete
          await promise;
        } else {
          console.log(`File already exists. Skipping download.`);
        }

        setFile({
          url: EPUB_PATH,
          initialLocation: INITIAL_LOCATION,
        });
      }
    }

    run()
  }, []);

  function updateHighlights(locator: Locator) {
    console.log("updateHighlights");
    const newHighlight = {
      id: highlightId,
      locator: locator,
    };
    setHighlights(prev => [...prev, newHighlight]);
    setHighlightId(prev => prev + 1);
  }

  function deleteHighlight(highlight: Highlight) {
    console.log(`delete highlight: ${highlight.id}`);
    const newHighlights = highlights.filter(item => item.id !== highlight.id);
    setHighlights(newHighlights);
  }

  if (file) {
    return (
      <View style={styles.container}>
        <View style={styles.controls}>
          <View style={styles.button}>
            <CoverImageView
              epubPath={EPUB_PATH}
            />
          </View>
          <View style={styles.button}>
            <TableOfContents
              items={toc}
              onPress={(loc) => setLocation({ href: loc.href, type: 'application/xhtml+xml', title: loc.title })}
            />
          </View>
          <View style={styles.button}>
            <ReaderSettings
              settings={settings}
              onSettingsChanged={(s) => setSettings(s)}
            />
          </View>
        </View>

        <View style={styles.reader}>
          {Platform.OS === 'web' ? (
            <ReaderButton
              name="chevron-left"
              style={{ width: '10%' }}
              onPress={() => ref.current?.prevPage()}
            />
          ) : null}
          <View style={styles.readiumContainer}>
            <ReadiumView
              ref={ref}
              file={file}
              location={location}
              settings={settings}
              highlights={highlights}
              onLocationChange={(locator: Locator) => setLocation(locator)}
              onTableOfContents={(toc: Link[] | null) => {
                if (toc) setToc(toc)
              }}
              onTranslate={locator => updateHighlights(locator)}
              onShowHighlight={ (highlight: Highlight) => console.log(`show highlight: ${highlight.id}`) }
              onDeleteHighlight={ (highlight: Highlight) => deleteHighlight(highlight) }
            />
          </View>
          {Platform.OS === 'web' ? (
            <ReaderButton
              name="chevron-right"
              style={{ width: '10%' }}
              onPress={() => ref.current?.nextPage()}
            />
          ) : null}
        </View>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text>downloading file</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: Platform.OS === 'web' ? '100vh' : '100%',
  },
  reader: {
    flexDirection: 'row',
    width: '100%',
    height: '90%',
  },
  readiumContainer: {
    width: Platform.OS === 'web' ? '80%' : '100%',
    height: '100%',
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
  },
  button: {
    margin: 10,
  },
});
