import React, { useState, useEffect } from 'react';
import { View, NativeModules } from 'react-native';
import { Overlay, Icon } from '@rneui/themed';
import { Image } from '@rneui/base';
import { DEFAULT_BOOKCOVER } from './consts';

export interface CoverImageViewProps {
  epubPath: string;
}

export const CoverImageView: React.FC<CoverImageViewProps> = ({
  epubPath,
}) => {
  const [isOpen, setIsOpen] = useState<boolean>(false);
  const onToggleOpen = () => setIsOpen(!isOpen);
  const [imageUri, setImageUri] = useState<string>(Image.resolveAssetSource(DEFAULT_BOOKCOVER).uri);
  const { CoverImageModule } = NativeModules;

  useEffect(() => {
    async function run() {
      try {
        const coverImage = await CoverImageModule.getCoverImage(epubPath, 300, 300);
        setImageUri(coverImage);
      } catch (err) {
      }
    }
    run();
  }, []);

  return (
    <View>
      <Icon
        name="image"
        type="font-awesome"
        size={30}
        onPress={onToggleOpen}
      />
      <Overlay
        isVisible={isOpen}
        onBackdropPress={onToggleOpen}
        overlayStyle={{
          width: '90%',
          marginVertical: 10,
        }}
      >
        <Image style={{ resizeMode: 'contain', width: '100%', height: undefined, aspectRatio: 1 }}
          source={{ uri: imageUri }} />
      </Overlay>
    </View>
  );
}