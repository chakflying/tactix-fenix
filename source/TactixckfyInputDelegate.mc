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

  //! The onPowerBudgetExceeded callback is called by the system if the
  //! onPartialUpdate method exceeds the allowed power budget. If this occurs,
  //! the system will stop invoking onPartialUpdate each second, so we notify the
  //! view here to let the rendering methods know they should not be rendering a
  //! second hand.
  //! @param powerInfo Information about the power budget
  public function onPowerBudgetExceeded(
    powerInfo as WatchFacePowerInfo
  ) as Void {
    System.println("Average execution time: " + powerInfo.executionTimeAverage);
    System.println("Allowed execution time: " + powerInfo.executionTimeLimit);
    _parentView.turnPartialUpdatesOff();
  }
}
