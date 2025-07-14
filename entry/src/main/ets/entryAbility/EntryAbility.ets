import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { HistoryDbInit } from '../common/dataStore/HistoryData';
import { saveAvatarCacheState } from '../common/component/Avatar';
import { BusinessError } from '@kit.BasicServicesKit';
import { PreferenceManager } from '../config/UserConfig';
import { initAccountManager } from '../common/account/AccountManager';
import { DraftDbInit } from '../common/dataStore/DraftData';
import { initJsonStorage } from '../common/dataStore/JsonPersist';
import { Event } from '../common/Events';
import { PropKey, SafeArea } from '../common/Constants';
import { CacheDbInit } from '../common/dataStore/ApiCacheData';
import { SmilyImageCacheInit } from '../common/dataStore/SmilyCache';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    PreferenceManager.init(this.context)
    HistoryDbInit(this.context)
    DraftDbInit(this.context)
    CacheDbInit(this.context)
    SmilyImageCacheInit(this.context)
    initAccountManager()
    initJsonStorage(this.context.filesDir)
    AppStorage.setOrCreate(PropKey.currentColorMode, this.context.config.colorMode)
    if (want.uri) {
      this.wantWithUri(want.uri)
    }
  }

  wantWithUri(uri: string) {
    this.context.eventHub.emit(Event.WantWithUri, uri)
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    if (want.uri) {
      this.wantWithUri(want.uri)
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {

    windowStage.loadContent('pages/NavProvider/NavigationPage', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      let windowClass: window.Window = windowStage.getMainWindowSync()
      let isLayoutFullScreen = true
      windowClass.setWindowLayoutFullScreen(isLayoutFullScreen).then(() => {
        // 把安全区大小挂到状态上
        let type = window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR
        let avoidArea = windowClass.getWindowAvoidArea(type)
        let bottomRectHeight = avoidArea.bottomRect.height
        AppStorage.setOrCreate(SafeArea.bottom, bottomRectHeight)

        type = window.AvoidAreaType.TYPE_SYSTEM
        avoidArea = windowClass.getWindowAvoidArea(type);
        let topRectHeight = avoidArea.topRect.height
        AppStorage.setOrCreate(SafeArea.top, topRectHeight)

        windowClass.on('avoidAreaChange', (data) => {
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
            AppStorage.setOrCreate(SafeArea.top, data.area.topRect.height)
          } else if (data.type == window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
            AppStorage.setOrCreate(SafeArea.bottom, data.area.bottomRect.height)
          } else if (data.type == window.AvoidAreaType.TYPE_KEYBOARD) {
            AppStorage.setOrCreate(SafeArea.keyboard, data.area.bottomRect.height)
          }
        })
      }).catch((err: BusinessError) => {
        console.error('Failed to set the window layout to full-screen mode. Cause:' + JSON.stringify(err));
      })
    })
  }

  onBackground(): void {
    saveAvatarCacheState()
  }

  onConfigurationUpdate(newConfig: Configuration) {
    AppStorage.setOrCreate(PropKey.currentColorMode, newConfig.colorMode)
  }
}
