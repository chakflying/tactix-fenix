import Toybox.Application;
import Toybox.Complications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;
import Toybox.Weather;

class TactixckfyView extends WatchUi.WatchFace {
  private var _isAwake as Boolean;
  private var _showWatchHands as Boolean;

  private var _fullScreenRefresh as Boolean;
  private var _offscreenBuffer as BufferedBitmap?;
  private var _screenCenterPoint as Array<Number>?;

  // Drawables
  private var bluetoothIconReference as BitmapReference?;
  private var dndIconReference as BitmapReference?;
  private var rainIconReference as BitmapReference?;
  private var spo2IconReference as BitmapReference?;

  // Complications
  private var currentTemp as Number?;
  private var currentTempComplicationId as Complications.Id?;

  private var currentQNH as Float?;
  private var currentQNHComplicationId as Complications.Id?;

  private var currentStep as Number?;
  private var currentStepComplicationId as Complications.Id?;

  private var currentHR as Number?;
  private var currentHRComplicationId as Complications.Id?;

  private var currentBodyBatt as Number?;
  private var currentBodyBattComplicationId as Complications.Id?;

  private var nextSunrise as Number?;
  private var nextSunriseComplicationId as Complications.Id?;

  private var nextSunset as Number?;
  private var nextSunsetComplicationId as Complications.Id?;

  private var currentWeather as CurrentConditions?;

  function initialize() {
    WatchFace.initialize();

    _fullScreenRefresh = true;
    _isAwake = true;
    _showWatchHands = true;

    checkComplications();
  }

  // Load your resources here
  function onLayout(dc as Dc) as Void {
    _offscreenBuffer = Graphics.createBufferedBitmap({
      :width => dc.getWidth(),
      :height => dc.getHeight(),
    }).get();

    setLayout(Rez.Layouts.WatchFace(_offscreenBuffer.getDc()));

    _screenCenterPoint =
      [dc.getWidth() / 2, dc.getHeight() / 2] as Array<Number>;

    bluetoothIconReference =
      WatchUi.loadResource($.Rez.Drawables.bluetoothIcon) as BitmapReference;
    dndIconReference =
      WatchUi.loadResource($.Rez.Drawables.dndIcon) as BitmapReference;
    rainIconReference =
      WatchUi.loadResource($.Rez.Drawables.rainIcon) as BitmapReference;
    spo2IconReference =
      WatchUi.loadResource($.Rez.Drawables.spo2Icon) as BitmapReference;
  }

  // Called when this View is brought to the foreground. Restore
  // the state of this View and prepare it to be shown. This includes
  // loading resources into memory.
  function onShow() as Void {
    subscribeComplications();
    View.onShow();
  }

  // Update the view
  function onUpdate(dc as Dc) as Void {
    // We always want to refresh the full screen when we get a regular onUpdate call.
    _fullScreenRefresh = true;

    // Get latest Weather
    currentWeather = Weather.getCurrentConditions();

    drawOffscreenBuffer(_offscreenBuffer.getDc());

    swapOffscreenToMain(dc);

    if (_isAwake && _screenCenterPoint != null) {
      drawSecondHand(dc);
    }
  }

  // Called when this View is removed from the screen. Save the
  // state of this View here. This includes freeing resources from
  // memory.
  function onHide() as Void {
    unsubscribeComplications();
    View.onHide();
  }

  // The user has just looked at their watch. Timers and animations may be started here.
  function onExitSleep() as Void {
    _isAwake = true;
  }

  // Terminate any active timers and prepare for slow updates.
  function onEnterSleep() as Void {
    _isAwake = false;
    WatchUi.requestUpdate();
  }

  public function toggleWatchHands() as Void {
    _showWatchHands = !_showWatchHands;
    WatchUi.requestUpdate();
  }

  private function swapOffscreenToMain(dc as Dc) as Void {
    dc.drawBitmap(0, 0, _offscreenBuffer);
  }

  private function drawOffscreenBuffer(dc as Dc) as Void {
    setTimeLabel();
    setDateLabel();
    setTemperatureLabel();
    setPercipLabel();
    setBloodOxyLabel();

    setTopLeftData();
    setTopRightData();
    setLowerLeftData();
    setLowerRightData();
    setBatDData();

    // Call the parent onUpdate function to redraw the layout
    View.onUpdate(dc);

    if (_screenCenterPoint != null) {
      drawStatusArcs(dc);
    }

    drawSunEventsMarkers(dc);

    // Draw the tick marks around the edges of the screen
    drawTickMarks(dc);

    drawDividers(dc);

    drawStatusIcons(dc);

    if (_screenCenterPoint != null) {
      drawWatchHands(dc);
    }
  }

  private function setTimeLabel() as Void {
    // Get the current time and format it correctly
    var timeFormat = "$1$:$2$";
    var clockTime = System.getClockTime();
    var hours = clockTime.hour;
    if (!System.getDeviceSettings().is24Hour) {
      if (hours > 12) {
        hours = hours - 12;
      }
    } else {
      if (Properties.getValue("UseMilitaryFormat")) {
        timeFormat = "$1$$2$";
        hours = hours.format("%02d");
      }
    }
    var timeString = Lang.format(timeFormat, [
      hours,
      clockTime.min.format("%02d"),
    ]);

    // Update the view
    var timeLabel = View.findDrawableById("TimeLabel") as Text;
    timeLabel.setColor(Properties.getValue("ForegroundColor") as Number);
    timeLabel.setText(timeString);
  }

  private function setDateLabel() as Void {
    var today = Time.today() as Time.Moment;
    var info = Gregorian.info(today, Time.FORMAT_MEDIUM);
    var dateString = Lang.format("$1$ $2$ $3$", [
      (info.day_of_week as Lang.String).toUpper(),
      info.day.format("%02d"),
      (info.month as Lang.String).toUpper(),
    ]);

    var dateLabel = View.findDrawableById("DateLabel") as Text;
    dateLabel.setColor(Properties.getValue("SubHeadingColor") as Number);
    dateLabel.setText(dateString);
  }

  private function setTemperatureLabel() as Void {
    var tempString = "--°C";
    if (currentTemp != null) {
      tempString = Lang.format("$1$°C", [currentTemp.format("%d")]);
    }

    var temperatureLabel = View.findDrawableById("TemperatureLabel") as Text;
    temperatureLabel.setColor(Properties.getValue("SubHeadingColor") as Number);
    temperatureLabel.setText(tempString);
  }

  private function setPercipLabel() as Void {
    var percipString = "--%";

    if (currentWeather != null) {
      if (currentWeather.precipitationChance != null) {
        percipString = Lang.format("$1$%", [
          currentWeather.precipitationChance.format("%d"),
        ]);
      }
    }

    var percipLabel = View.findDrawableById("PercipLabel") as Text;
    percipLabel.setColor(Properties.getValue("SubHeadingColor") as Number);
    percipLabel.setText(percipString);
  }

  private function setBloodOxyLabel() as Void {
    var bloodOxyString = "--%";
    var oxyHistoryIter = SensorHistory.getOxygenSaturationHistory({
      :period => 1,
    });

    var oxySample = oxyHistoryIter.next();
    if (oxySample != null) {
      var now = Time.now() as Time.Moment;
      var elapsed = now.subtract(oxySample.when) as Time.Duration;
      var twoHours = new Time.Duration(7200);
      if (elapsed.lessThan(twoHours) && oxySample.data != null) {
        bloodOxyString = Lang.format("$1$%", [oxySample.data.format("%d")]);
      }
    }

    var bloodOxyLabel = View.findDrawableById("BloodOxyLabel") as Text;
    bloodOxyLabel.setColor(Properties.getValue("SubHeadingColor") as Number);
    bloodOxyLabel.setText(bloodOxyString);
  }

  private function setBatDData() as Void {
    var battD = System.getSystemStats().batteryInDays.format("%.0f");
    var battDString = Lang.format("$1$d", [battD]);
    var battDLabel = View.findDrawableById("battDLabel") as Text;
    battDLabel.setColor(Properties.getValue("SubHeadingColor") as Number);
    battDLabel.setText(battDString);
  }

  private function setTopLeftData() as Void {
    var labelLabel = View.findDrawableById("topLeftLabelLabel") as Text;
    labelLabel.setText("BARO");

    var currentQNHString = "----";
    if (currentQNH != null) {
      currentQNHString = (currentQNH / 100).format("%.1f");
      var dataLabel = View.findDrawableById("topLeftDataLabel") as Text;
      dataLabel.setText(currentQNHString);
    }
  }

  private function setTopRightData() as Void {
    var labelLabel = View.findDrawableById("topRightLabelLabel") as Text;
    labelLabel.setText("WIND");

    var currentWindString = "----";
    if (currentWeather != null) {
      currentWindString = Lang.format("$1$ $2$", [
        (currentWeather.windSpeed * 3.6).format("%.0f"),
        bearingToDirection(currentWeather.windBearing),
      ]);
      var dataLabel = View.findDrawableById("topRightDataLabel") as Text;
      dataLabel.setText(currentWindString);
    }
  }

  private function setLowerLeftData() as Void {
    var labelLabel = View.findDrawableById("lowerLeftLabelLabel") as Text;
    labelLabel.setText("STEP");

    if (currentStep != null) {
      var dataLabel = View.findDrawableById("lowerLeftDataLabel") as Text;
      dataLabel.setText(currentStep.format("%d"));
    }
  }

  private function setLowerRightData() as Void {
    var labelLabel = View.findDrawableById("lowerRightLabelLabel") as Text;
    labelLabel.setText("HR");

    var currentHRString = "--";
    if (currentHR != null) {
      currentHRString = currentHR.format("%d");
      var dataLabel = View.findDrawableById("lowerRightDataLabel") as Text;
      dataLabel.setText(currentHRString);
    }
  }

  private function bearingToDirection(bearing as Number) as String {
    if (bearing < 23) {
      return "N";
    } else if (bearing < 68) {
      return "NE";
    } else if (bearing < 113) {
      return "E";
    } else if (bearing < 158) {
      return "SE";
    } else if (bearing < 203) {
      return "S";
    } else if (bearing < 248) {
      return "SW";
    } else if (bearing < 293) {
      return "W";
    } else if (bearing < 338) {
      return "NW";
    } else {
      return "N";
    }
  }

  private const smallHashLength = 4;
  private const bigHashLength = 12;
  //! Draws the clock tick marks around the outside edges of the screen.
  //! @param dc Device context
  private function drawTickMarks(dc as Dc) as Void {
    dc.setAntiAlias(true);
    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);

    var width = dc.getWidth();

    var outerRad = width / 2;

    for (var i = 0; i <= 59; i++) {
      var angle = (i * 6 * Math.PI) / 180;
      var innerRad = outerRad - smallHashLength;
      if (i % 5 == 0) {
        innerRad = outerRad - bigHashLength;
        dc.setPenWidth(3);
        //dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
      } else {
        dc.setPenWidth(1);
      }
      // Partially unrolled loop to draw two tickmarks in 15 minute block.
      var sY = outerRad + innerRad * Math.sin(angle);
      var eY = outerRad + outerRad * Math.sin(angle);
      var sX = outerRad + innerRad * Math.cos(angle);
      var eX = outerRad + outerRad * Math.cos(angle);
      dc.drawLine(sX, sY, eX, eY);
    }
  }

  private function drawDividers(dc as Dc) as Void {
    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
    dc.drawLine(40, 75, 220, 75);
    dc.drawLine(40, 185, 220, 185);
    dc.drawLine(130, 30, 130, 75);
    dc.drawLine(130, 30, 130, 75);
    dc.drawLine(130, 185, 130, 230);
  }

  private function drawStatusIcons(dc as Dc) as Void {
    dc.setAntiAlias(true);

    var deviceSettings = System.getDeviceSettings();

    if (bluetoothIconReference != null) {
      if (deviceSettings.phoneConnected) {
        var bluetoothIconBitmap =
          bluetoothIconReference.get() as BitmapResource;
        dc.drawBitmap2(25, 122, bluetoothIconBitmap, {});
      }
    }
    if (dndIconReference != null) {
      if (deviceSettings.doNotDisturb) {
        var dndIconBitmap = dndIconReference.get() as BitmapResource;
        dc.drawBitmap2(220, 123, dndIconBitmap, {});
      }
    }
    if (rainIconReference != null) {
      var rainIconBitmap = rainIconReference.get() as BitmapResource;
      dc.drawBitmap2(203, 163, rainIconBitmap, {
        :tintColor => Properties.getValue("SubHeadingColor") as Number,
      });
    }
    if (spo2IconReference != null) {
      var spo2IconBitmap = spo2IconReference.get() as BitmapResource;
      dc.drawBitmap2(42, 162, spo2IconBitmap, {
        :tintColor => Properties.getValue("SubHeadingColor") as Number,
      });
    }
  }

  private function drawStatusArcs(dc as Dc) as Void {
    dc.setAntiAlias(true);

    var arcRadius = 129;

    var battery = (System.getSystemStats().battery as Lang.Float) / 100;
    if (battery < 0.3) {
      dc.setColor(0xaa0000, Graphics.COLOR_BLACK);
    } else if (battery < 0.5) {
      dc.setColor(0xffaa00, Graphics.COLOR_BLACK);
    } else {
      dc.setColor(0x005500, Graphics.COLOR_BLACK);
    }
    dc.setPenWidth(2);
    dc.drawArc(
      _screenCenterPoint[0],
      _screenCenterPoint[1],
      arcRadius,
      Graphics.ARC_CLOCKWISE,
      270,
      270 - 180 * battery
    );

    if (currentBodyBatt != null) {
      var bodyBatt = currentBodyBatt.toFloat() / 100.0;
      if (bodyBatt < 0.3) {
        dc.setColor(0xaa0000, Graphics.COLOR_BLACK);
      } else if (bodyBatt < 0.5) {
        dc.setColor(0x00aaaa, Graphics.COLOR_BLACK);
      } else {
        dc.setColor(0x0000aa, Graphics.COLOR_BLACK);
      }

      var arcEnd = (270 + 180 * bodyBatt).toNumber() % 360;
      if (arcEnd == 270) {
        arcEnd = 271;
      }

      dc.setPenWidth(2);
      dc.drawArc(
        _screenCenterPoint[0],
        _screenCenterPoint[1],
        arcRadius,
        Graphics.ARC_COUNTER_CLOCKWISE,
        270,
        arcEnd
      );
    }
  }

  private function drawSunEventsMarkers(dc as Dc) as Void {
    dc.setAntiAlias(true);

    if (nextSunrise != null) {
      var nextSunriseAngle =
        (nextSunrise.toFloat() / (60 * 60 * 12)) * Math.PI * 2;

      dc.setColor(0x0055AA, Graphics.COLOR_BLACK);
      dc.fillPolygon(getLeftTriangleMarker(_screenCenterPoint, nextSunriseAngle));
      dc.setColor(0xffaaaa, Graphics.COLOR_BLACK);
      dc.fillPolygon(getRightTriangleMarker(_screenCenterPoint, nextSunriseAngle));
    }

    if (nextSunset != null) {
      var nextSunsetAngle =
        (nextSunset.toFloat() / (60 * 60 * 12)) * Math.PI * 2;

      dc.setColor(0xff5500, Graphics.COLOR_BLACK);
      dc.fillPolygon(getLeftTriangleMarker(_screenCenterPoint, nextSunsetAngle));
      dc.setColor(0x0055AA, Graphics.COLOR_BLACK);
      dc.fillPolygon(getRightTriangleMarker(_screenCenterPoint, nextSunsetAngle));
    }
  }

  private function drawWatchHands(dc as Dc) as Void {
    dc.setAntiAlias(true);
    var clockTime = System.getClockTime();

    if (_showWatchHands) {
      var hourHandAngle =
        (((clockTime.hour % 12) * 60 + clockTime.min) / (12 * 60.0)) *
        Math.PI *
        2;

      var minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;

      dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
      dc.fillPolygon(getHourHandPoints(_screenCenterPoint, hourHandAngle));
      dc.fillPolygon(getMinuteHandPoints(_screenCenterPoint, minuteHandAngle));
    }
  }

  private function drawSecondHand(dc as Dc) as Void {
    dc.setAntiAlias(true);
    var clockTime = System.getClockTime();

    var secondHandAngle = (clockTime.sec / 60.0) * Math.PI * 2;

    dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
    dc.fillPolygon(getSecondHandPoints(_screenCenterPoint, secondHandAngle));
  }

  private function getHourHandPoints(
    centerPoint as Array<Number>,
    angle as Float
  ) as Array<Array<Float> > {
    // Map out the coordinates of the watch hand pointing down
    var coords =
      [
        [-(10 / 2), -40] as Array<Number>,
        [-(18 / 2), -70] as Array<Number>,
        [0, -93] as Array<Number>,
        [18 / 2, -70] as Array<Number>,
        [10 / 2, -40] as Array<Number>,
      ] as Array<Array<Number> >;

    return rotatePoints(centerPoint, coords, angle);
  }

  private function getMinuteHandPoints(
    centerPoint as Array<Number>,
    angle as Float
  ) as Array<Array<Float> > {
    // Map out the coordinates of the watch hand pointing down
    var coords =
      [
        [-(10 / 2), -45] as Array<Number>,
        [-(10 / 2), -115] as Array<Number>,
        [0, -125] as Array<Number>,
        [10 / 2, -115] as Array<Number>,
        [10 / 2, -45] as Array<Number>,
      ] as Array<Array<Number> >;

    return rotatePoints(centerPoint, coords, angle);
  }

  private function getSecondHandPoints(
    centerPoint as Array<Number>,
    angle as Float
  ) as Array<Array<Float> > {
    // Map out the coordinates of the watch hand pointing down
    var coords =
      [
        [-(4 / 2), -30] as Array<Number>,
        [-(4 / 2), -125] as Array<Number>,
        [0, -130] as Array<Number>,
        [4 / 2, -125] as Array<Number>,
        [4 / 2, -30] as Array<Number>,
      ] as Array<Array<Number> >;

    return rotatePoints(centerPoint, coords, angle);
  }

  private function getLeftTriangleMarker(
    centerPoint as Array<Number>,
    angle as Float
  ) as Array<Array<Float> > {
    var coords =
      [
        [-(16 / 2), -113] as Array<Number>,
        [0, -130] as Array<Number>,
        [0, -113] as Array<Number>,
      ] as Array<Array<Number> >;

    return rotatePoints(centerPoint, coords, angle);
  }

  private function getRightTriangleMarker(
    centerPoint as Array<Number>,
    angle as Float
  ) as Array<Array<Float> > {
    var coords =
      [
        [0, -113] as Array<Number>,
        [0, -130] as Array<Number>,
        [16 / 2, -113] as Array<Number>,
      ] as Array<Array<Number> >;

    return rotatePoints(centerPoint, coords, angle);
  }

  // Rotate an array of points around the centerPoint
  private function rotatePoints(
    centerPoint as Array<Number>,
    points as Array<Array<Number> >,
    angle as Float
  ) {
    var result = new Array<Array<Float> >[points.size()];
    var cos = Math.cos(angle);
    var sin = Math.sin(angle);

    // Transform the coordinates
    for (var i = 0; i < points.size(); i++) {
      var x = points[i][0] * cos - points[i][1] * sin + 0.5;
      var y = points[i][0] * sin + points[i][1] * cos + 0.5;

      result[i] = [centerPoint[0] + x, centerPoint[1] + y] as Array<Float>;
    }

    return result;
  }

  private function checkComplications() as Void {
    System.println("Checking complications...");
    var iter = Complications.getComplications();

    var complication = iter.next();
    while (complication != null) {
      if (
        complication.getType() ==
        Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE
      ) {
        currentTempComplicationId = complication.complicationId;
      }

      if (
        complication.getType() ==
        Complications.COMPLICATION_TYPE_SEA_LEVEL_PRESSURE
      ) {
        currentQNHComplicationId = complication.complicationId;
      }

      if (complication.getType() == Complications.COMPLICATION_TYPE_STEPS) {
        currentStepComplicationId = complication.complicationId;
      }

      if (
        complication.getType() == Complications.COMPLICATION_TYPE_HEART_RATE
      ) {
        currentHRComplicationId = complication.complicationId;
      }

      if (
        complication.getType() == Complications.COMPLICATION_TYPE_BODY_BATTERY
      ) {
        currentBodyBattComplicationId = complication.complicationId;
      }

      if (complication.getType() == Complications.COMPLICATION_TYPE_SUNRISE) {
        nextSunriseComplicationId = complication.complicationId;
      }

      if (complication.getType() == Complications.COMPLICATION_TYPE_SUNSET) {
        nextSunsetComplicationId = complication.complicationId;
      }

      complication = iter.next();
    }
  }

  private function subscribeComplications() as Void {
    Complications.registerComplicationChangeCallback(
      self.method(:onComplicationChanged)
    );

    if (currentTempComplicationId != null) {
      Complications.subscribeToUpdates(currentTempComplicationId);
    }

    if (currentQNHComplicationId != null) {
      Complications.subscribeToUpdates(currentQNHComplicationId);
    }

    if (currentStepComplicationId != null) {
      Complications.subscribeToUpdates(currentStepComplicationId);
    }

    if (currentHRComplicationId != null) {
      Complications.subscribeToUpdates(currentHRComplicationId);
    }

    if (currentBodyBattComplicationId != null) {
      Complications.subscribeToUpdates(currentBodyBattComplicationId);
    }

    if (nextSunriseComplicationId != null) {
      Complications.subscribeToUpdates(nextSunriseComplicationId);
    }

    if (nextSunsetComplicationId != null) {
      Complications.subscribeToUpdates(nextSunsetComplicationId);
    }
  }

  private function unsubscribeComplications() as Void {
    Complications.unsubscribeFromAllUpdates();
    Complications.registerComplicationChangeCallback(null);
  }

  function onComplicationChanged(complicationId as Complications.Id) as Void {
    var data = Complications.getComplication(complicationId);
    var dataValue = data.value;

    if (complicationId == currentTempComplicationId) {
      if (dataValue != null) {
        currentTemp = dataValue as Lang.Number;
      }
    }

    if (complicationId == currentQNHComplicationId) {
      if (dataValue != null) {
        currentQNH = dataValue as Lang.Float;
      }
    }

    if (complicationId == currentStepComplicationId) {
      if (dataValue != null) {
        currentStep = dataValue as Lang.Number;
      }
    }

    if (complicationId == currentHRComplicationId) {
      if (dataValue != null) {
        currentHR = dataValue as Lang.Number;
      }
    }

    if (complicationId == currentBodyBattComplicationId) {
      if (dataValue != null) {
        currentBodyBatt = dataValue as Lang.Number;
      }
    }

    if (complicationId == nextSunriseComplicationId) {
      if (dataValue != null) {
        nextSunrise = dataValue as Lang.Number;
      }
    }

    if (complicationId == nextSunsetComplicationId) {
      if (dataValue != null) {
        nextSunset = dataValue as Lang.Number;
      }
    }
  }
}
