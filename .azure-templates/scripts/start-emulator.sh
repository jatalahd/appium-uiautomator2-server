#!/usr/bin/env bash

# This script was copy-pasted from https://docs.microsoft.com/en-us/azure/devops/pipelines/languages/android?view=azure-devops#test-on-the-android-emulator
# with some changes

echo $ANDROID_HOME/emulator/emulator -list-avds

# Install AVD files
declare -r emulator="system-images;android-$ANDROID_SDK_VERSION;$EMU_TAG;$EMU_ARCH"
echo "y" | $ANDROID_HOME/tools/bin/sdkmanager --install "$emulator"

# Create emulator
echo "no" | $ANDROID_HOME/tools/bin/avdmanager create avd -n $ANDROID_AVD -k "$emulator" -c 1500M --force

echo "Starting emulator"

# Start emulator in background
nohup $ANDROID_HOME/emulator/emulator -avd $ANDROID_AVD -no-snapshot > /dev/null 2>&1 &
#$ANDROID_HOME/platform-tools/adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed | tr -d '\r') ]]; do sleep 1; done; input keyevent 82'

adb wait-for-device get-serialno
secondsStarted=`date +%s`
TIMEOUT=360
while [[ $(( `date +%s` - $secondsStarted )) -lt $TIMEOUT ]]; do
  # Fail fast if Emulator process crashed
  pgrep -nf avd || exit 1

  pstat=$(adb shell ps)
  if ! [[ $pstat =~ "root " ]]; then
    # In recent APIs running `ps` without `-A` only returns
    # processes belonging to the current user (in this case `shell`)
    pstat=$(adb shell ps -A)
  fi

  if [[ $pstat =~ "com.android.systemui" ]]; then
    echo "System UI process is running. Checking services availability"
    if adb shell "ime list && pm get-install-location && echo PASS" | grep -q "PASS"; then
      break
    fi
  fi

  sleep 5
  secondsElapsed=$(( `date +%s` - $secondsStarted ))
  secondsLeft=$(( $TIMEOUT - $secondsElapsed ))
  echo "Waiting until emulator finishes services startup; ${secondsElapsed}s elapsed; ${secondsLeft}s left"
done

bootDuration=$(( `date +%s` - $secondsStarted ))
if [[ $bootDuration -ge $TIMEOUT ]]; then
  echo "Emulator has failed to fully start within ${TIMEOUT}s"
  exit 1
fi
echo "Emulator booting took ${bootDuration}s"
adb shell input keyevent 82

adb devices -l
