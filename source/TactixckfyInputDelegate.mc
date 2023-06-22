import Toybox.Lang;
import Toybox.WatchUi;

class TactixckfyInputDelegate extends WatchUi.WatchFaceDelegate {
  private var _parentView as TactixckfyView?;

  public function initialize(view as TactixckfyView) {
    WatchUi.WatchFaceDelegate.initialize();
    _parentView = view;
  }

  public function onPress(clickEvent) as Lang.Boolean {
    _parentView.toggleWatchHands();
    return true;
  }
}
