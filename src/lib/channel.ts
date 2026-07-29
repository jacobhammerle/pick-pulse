import * as Updates from 'expo-updates';

/**
 * Channel surfing: point this installed build at a different
 * EAS Update channel at runtime. Used to preview PR updates
 * inside the app during the demo.
 * Requires a release build (not a dev client). SDK 54+.
 */
export async function switchChannelAsync(channel: string): Promise<void> {
  Updates.setUpdateRequestHeadersOverride({
    'expo-channel-name': channel,
  });

  const update = await Updates.checkForUpdateAsync();
  if (update.isAvailable) {
    await Updates.fetchUpdateAsync();
  }
  await Updates.reloadAsync();
}

/** Clear the override and return to the channel embedded in the build. */
export async function resetChannelAsync(): Promise<void> {
  Updates.setUpdateRequestHeadersOverride(null);

  const update = await Updates.checkForUpdateAsync();
  if (update.isAvailable) {
    await Updates.fetchUpdateAsync();
  }
  await Updates.reloadAsync();
}

export function getUpdateInfo() {
  return {
    isEnabled: Updates.isEnabled,
    channel: Updates.channel,
    updateId: Updates.updateId,
    runtimeVersion: Updates.runtimeVersion,
    isEmbedded: Updates.isEmbeddedLaunch,
  };
}
