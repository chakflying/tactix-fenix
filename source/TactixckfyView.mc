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
  private var _partialUpdatesAllowed as Boolean;

  private var clockTime as ClockTime;

  private var _fullScreenRefresh as Boolean;
  private var _offscreenBuffer as BufferedBitmap?;
  private var _screenCenterPoint as Array<Number>?;

  // Drawables
  private var bluetoothIconReference as BitmapReference?;
  private var dndIconReference as BitmapReference?;
  private var rainIconReference as BitmapReference?;
  private var spo2IconReference as BitmapReference?;
  private var moonPhaseReferences as Array<BitmapReference>?;

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

  // Layout References
  private var timeLabel as Text?;
  private var dateLabel as Text?;
  private var temperatureLabel as Text?;
  private var percipLabel as Text?;
  private var bloodOxyLabel as Text?;
  private var battDLabel as Text?;
  private var tLLabelLabel as Text?;
  private var tLDataLabel as Text?;
  private var tRLabelLabel as Text?;
  private var tRDataLabel as Text?;
  private var bLLabelLabel as Text?;
  private var bLDataLabel as Text?;
  private var bRLabelLabel as Text?;
  private var bRDataLabel as Text?;

  private var currentMoonphase as Number?;
  private var moonphaseLastCalculated as Moment?;

  function initialize() {
    WatchFace.initialize();

    _fullScreenRefresh = true;
    _isAwake = true;
    _showWatchHands = true;
    _partialUpdatesAllowed = WatchUi.WatchFace has :onPartialUpdate;
    clockTime = System.getClockTime();

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

    moonPhaseReferences = new Array<BitmapReference>[8];
    moonPhaseReferences[0] =
      WatchUi.loadResource($.Rez.Drawables.moonphase0) as BitmapReference;
    moonPhaseReferences[1] =
      WatchUi.loadResource($.Rez.Drawables.moonphase1) as BitmapReference;
    moonPhaseReferences[2] =
      WatchUi.loadResource($.Rez.Drawables.moonphase2) as BitmapReference;
    moonPhaseReferences[3] =
      WatchUi.loadResource($.Rez.Drawables.moonphase3) as BitmapReference;
    moonPhaseReferences[4] =
      WatchUi.loadResource($.Rez.Drawables.moonphase4) as BitmapReference;
    moonPhaseReferences[5] =
      WatchUi.loadResource($.Rez.Drawables.moonphase5) as BitmapReference;
    moonPhaseReferences[6] =
      WatchUi.loadResource($.Rez.Drawables.moonphase6) as BitmapReference;
    moonPhaseReferences[7] =
      WatchUi.loadResource($.Rez.Drawables.moonphase7) as BitmapReference;

    timeLabel = View.findDrawableById("TimeLabel") as Text;
    dateLabel = View.findDrawableById("DateLabel") as Text;
    temperatureLabel = View.findDrawableById("TemperatureLabel") as Text;
    percipLabel = View.findDrawableById("PercipLabel") as Text;
    bloodOxyLabel = View.findDrawableById("BloodOxyLabel") as Text;
    battDLabel = View.findDrawableById("battDLabel") as Text;
    tLLabelLabel = View.findDrawableById("topLeftLabelLabel") as Text;
    tLDataLabel = View.findDrawableById("topLeftDataLabel") as Text;
    tRLabelLabel = View.findDrawableById("topRightLabelLabel") as Text;
    tRDataLabel = View.findDrawableById("topRightDataLabel") as Text;
    bLLabelLabel = View.findDrawableById("bottomLeftLabelLabel") as Text;
    bLDataLabel = View.findDrawableById("bottomLeftDataLabel") as Text;
    bRLabelLabel = View.findDrawableById("bottomRightLabelLabel") as Text;
    bRDataLabel = View.findDrawableById("bottomRightDataLabel") as Text;
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
    clockTime = System.getClockTime();

    // We always want to refresh the full screen when we get a regular onUpdate call.
    _fullScreenRefresh = true;
    dc.clearClip();

    // Get latest Weather
    currentWeather = Weather.getCurrentConditions();

    drawOffscreenBuffer(_offscreenBuffer.getDc());

    swapOffscreenToMain(dc);

    if (_partialUpdatesAllowed) {
      onPartialUpdate(dc);
    } else if (_isAwake && _screenCenterPoint != null) {
      drawSecondHand(dc, false);
    }

    _fullScreenRefresh = false;
  }

  function onPartialUpdate(dc as Dc) as Void {
    clockTime = System.getClockTime();

    // If we're not doing a full screen refresh we need to re-draw the background
    // before drawing the updated second hand position. Note this will only re-draw
    // the background in the area specified by the previously computed clipping region.
    if (!_fullScreenRefresh) {
      swapOffscreenToMain(dc);
    }

    if (_screenCenterPoint != null) {
      drawSecondHand(dc, true);
    }
  }

  //! Turn off partial updates
  public function turnPartialUpdatesOff() as Void {
    _partialUpdatesAllowed = false;
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

    drawTickMarks(dc);

    drawDividers(dc);

    drawStatusIcons(dc);

    drawMoonPhase(dc);

    if (_screenCenterPoint != null) {
      drawWatchHands(dc);
    }
  }

  private function setTimeLabel() as Void {
    // Get the current time and format it correctly
    var timeFormat = "$1$:$2$";

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

    dateLabel.setColor(Properties.getValue("SubHeadingColor") as Number);
    dateLabel.setText(dateString);
  }

  private function setTemperatureLabel() as Void {
    var unitSetting = Properties.getValue("TemperatureUnit") as Number;

    var tempString = "--°C";
    if (unitSetting == 1) {
      tempString = "--°F";
    }

    if (currentTemp != null) {
      tempString = Lang.format("$1$°$2$", [
        unitSetting == 1
          ? celsiusToFahrenheit(currentTemp).format("%d")
          : currentTemp.format("%d"),
        unitSetting == 1 ? "F" : "C",
      ]);
    }

    temperatureLabel.setColor(Properties.getValue("SubHeadingColor") as Number);
    temperatureLabel.setText(tempString);
  }

  private function celsiusToFahrenheit(c as Number) as Number {
    return Math.round(c.toFloat() * 1.8 + 32).toNumber();
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

    bloodOxyLabel.setColor(Properties.getValue("SubHeadingColor") as Number);
    bloodOxyLabel.setText(bloodOxyString);
  }

  private function setBatDData() as Void {
    var battD = System.getSystemStats().batteryInDays.format("%.0f");
    var battDString = Lang.format("$1$d", [battD]);

    battDLabel.setColor(Properties.getValue("SubHeadingColor") as Number);
    battDLabel.setText(battDString);
  }

  private function setTopLeftData() as Void {
    tLLabelLabel.setText("BARO");

    var currentQNHString = "----";
    if (currentQNH != null) {
      currentQNHString = (currentQNH / 100).format("%.1f");
      tLDataLabel.setText(currentQNHString);
    }
  }

  private function setTopRightData() as Void {
    tRLabelLabel.setText("WIND");

    var unitConversionFactor = 1.0;
    if (Properties.getValue("WindSpeedUnit") == 0) {
      unitConversionFactor = 3.6;
    } else if (Properties.getValue("WindSpeedUnit") == 2) {
      unitConversionFactor = 1.944;
    }

    var currentWindString = "----";
    if (currentWeather != null) {
      if (
        currentWeather.windSpeed != null &&
        currentWeather.windBearing != null
      ) {
        if (currentWeather.windSpeed < 0.5) {
          currentWindString = "CALM";
        } else {
          currentWindString = Lang.format("$1$ $2$", [
            Math.round(currentWeather.windSpeed * unitConversionFactor).format(
              "%.0f"
            ),
            bearingToDirection(currentWeather.windBearing),
          ]);
        }
      }

      tRDataLabel.setText(currentWindString);
    }
  }

  private function setLowerLeftData() as Void {
    bLLabelLabel.setText("STEP");

    if (currentStep != null) {
      if (currentStep instanceof Float) {
        bLDataLabel.setText((currentStep * 1000).format("%.0f"));
      } else {
        bLDataLabel.setText(currentStep.format("%d"));
      }
    }
  }

  private function setLowerRightData() as Void {
    bRLabelLabel.setText("HR");

    var currentHRString = "--";
    if (currentHR != null) {
      currentHRString = currentHR.format("%d");
      bRDataLabel.setText(currentHRString);
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

    for (var i = 0; i <= 29; i++) {
      var angle = (i * 6 * Math.PI) / 180;
      var innerRad = outerRad - smallHashLength;
      if (i % 5 == 0) {
        innerRad = outerRad - bigHashLength;
        dc.setPenWidth(3);
      } else {
        dc.setPenWidth(1);
      }
      // Partially unrolled loop to draw two tickmarks
      var sY = outerRad + innerRad * Math.sin(angle);
      var eY = outerRad + outerRad * Math.sin(angle);
      var sX = outerRad + innerRad * Math.cos(angle);
      var eX = outerRad + outerRad * Math.cos(angle);
      dc.drawLine(sX, sY, eX, eY);
      dc.drawLine(260 - sX, 260 - sY, 260 - eX, 260 - eY);
    }
  }

  private function drawDividers(dc as Dc) as Void {
    dc.setPenWidth(1);
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

    var arcRadius = 128;
    dc.setPenWidth(4);

    var battery = (System.getSystemStats().battery as Lang.Float) / 100;
    if (battery < 0.3) {
      dc.setColor(0xaa0000, Graphics.COLOR_BLACK);
    } else if (battery < 0.5) {
      dc.setColor(0xffaa00, Graphics.COLOR_BLACK);
    } else {
      dc.setColor(0x005500, Graphics.COLOR_BLACK);
    }
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

      dc.setColor(0x0055aa, Graphics.COLOR_BLACK);
      dc.fillPolygon(
        getLeftTriangleMarker(_screenCenterPoint, nextSunriseAngle)
      );
      dc.setColor(0xffaaaa, Graphics.COLOR_BLACK);
      dc.fillPolygon(
        getRightTriangleMarker(_screenCenterPoint, nextSunriseAngle)
      );
    }

    if (nextSunset != null) {
      var nextSunsetAngle =
        (nextSunset.toFloat() / (60 * 60 * 12)) * Math.PI * 2;

      dc.setColor(0xff5500, Graphics.COLOR_BLACK);
      dc.fillPolygon(
        getLeftTriangleMarker(_screenCenterPoint, nextSunsetAngle)
      );
      dc.setColor(0x0055aa, Graphics.COLOR_BLACK);
      dc.fillPolygon(
        getRightTriangleMarker(_screenCenterPoint, nextSunsetAngle)
      );
    }
  }

  private function drawWatchHands(dc as Dc) as Void {
    dc.setAntiAlias(true);

    if (_showWatchHands) {
      var hourHandAngle =
        (((clockTime.hour % 12) * 60 + clockTime.min) / (12 * 60.0)) *
        Math.PI *
        2;

      var minuteHandAngle = (clockTime.min / 60.0) * Math.PI * 2;

      var hourHandPoints = getHourHandPoints(_screenCenterPoint, hourHandAngle);

      var minuteHandPoints = getMinuteHandPoints(
        _screenCenterPoint,
        minuteHandAngle
      );

      dc.setPenWidth(3);
      dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
      dc.fillPolygon(hourHandPoints);
      dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
      drawPolygon(dc, hourHandPoints);

      dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
      dc.fillPolygon(minuteHandPoints);
      dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
      drawPolygon(dc, minuteHandPoints);
    }
  }

  private function drawPolygon(dc as Dc, points as Array<Array<Float> >) {
    dc.setAntiAlias(true);
    var i;
    for (i = 1; i < points.size(); i++) {
      dc.drawLine(
        points[i - 1][0],
        points[i - 1][1],
        points[i][0],
        points[i][1]
      );
    }
    dc.drawLine(points[i - 1][0], points[i - 1][1], points[0][0], points[0][1]);
  }

  private function drawSecondHand(dc as Dc, setClip as Boolean) as Void {
    dc.setAntiAlias(true);

    var secondHandAngle = (clockTime.sec / 60.0) * Math.PI * 2;

    var secondHandPoints = getSecondHandPoints(
      _screenCenterPoint,
      secondHandAngle
    );

    if (setClip) {
      var curClip = getBoundingBox(secondHandPoints);
      var bBoxWidth = curClip[1][0] - curClip[0][0] + 1;
      var bBoxHeight = curClip[1][1] - curClip[0][1] + 1;
      dc.setClip(curClip[0][0], curClip[0][1], bBoxWidth, bBoxHeight);
    }

    dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_BLACK);
    dc.fillPolygon(secondHandPoints);
  }

  //! Compute a bounding box from the passed in points
  //! @param points Points to include in bounding box
  //! @return The bounding box points
  private function getBoundingBox(
    points as Array<Array<Number or Float> >
  ) as Array<Array<Number or Float> > {
    var min = [9999, 9999] as Array<Number>;
    var max = [0, 0] as Array<Number>;

    for (var i = 0; i < points.size(); ++i) {
      if (points[i][0] < min[0]) {
        min[0] = points[i][0];
      }

      if (points[i][1] < min[1]) {
        min[1] = points[i][1];
      }

      if (points[i][0] > max[0]) {
        max[0] = points[i][0];
      }

      if (points[i][1] > max[1]) {
        max[1] = points[i][1];
      }
    }

    return [min, max] as Array<Array<Number or Float> >;
  }

  private function getHourHandPoints(
    centerPoint as Array<Number>,
    angle as Float
  ) as Array<Array<Float> > {
    // Map out the coordinates of the watch hand pointing down
    var coords =
      [
        [-(12 / 2), -35] as Array<Number>,
        [-(22 / 2), -65] as Array<Number>,
        [0, -95] as Array<Number>,
        [22 / 2, -65] as Array<Number>,
        [12 / 2, -35] as Array<Number>,
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
        [-(12 / 2), -45] as Array<Number>,
        [-(12 / 2), -115] as Array<Number>,
        [0, -125] as Array<Number>,
        [12 / 2, -115] as Array<Number>,
        [12 / 2, -45] as Array<Number>,
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

  private function getMoonPhase(
    year as Number,
    mon as Number,
    day as Number,
    hour as Number
  ) as Number {
    /*
      calculates the moon phase (0-7), accurate to 1 segment.
      0 = > new moon.
      4 => full moon.
      implementation from sffjunkie/astral
      */

    var jd = getJulianDay(year, mon, day, hour);
    // System.println("Julian Day: " + jd.format("%f"));

    var dt = Math.pow(jd - 2382148.0, 2) / (41048480.0 * 86400.0);
    var t = (jd + dt - 2451545.0) / 36525.0;
    var t2 = Math.pow(t, 2);
    var t3 = Math.pow(t, 3);

    var d = 297.85 + 445267.1115 * t - 0.00163 * t2 + t3 / 545868.0;
    while (d > 360.0) {
      d -= 360.0;
    }
    d = Math.toRadians(d);

    var m = 357.53 + 35999.0503 * t;
    while (m > 360.0) {
      m -= 360.0;
    }
    m = Math.toRadians(m);

    var m1 = 134.96 + 477198.8676 * t + 0.008997 * t2 + t3 / 69699.0;
    while (m1 > 360.0) {
      m1 -= 360.0;
    }
    m1 = Math.toRadians(m1);

    var elong = Math.toDegrees(d) + 6.29 * Math.sin(m1);
    elong -= 2.1 * Math.sin(m);
    elong += 1.27 * Math.sin(2.0 * d - m1);
    elong += 0.66 * Math.sin(2.0 * d);
    while (elong > 360.0) {
      elong -= 360.0;
    }

    var moon = ((elong + 6.43) / 360.0) * 28.0;
    // System.println("Moon Phase: " + moon.format("%f"));
    return Math.round(moon / 4.0).toNumber();
  }

  private function getJulianDay(
    y as Number,
    m as Number,
    d as Number,
    h as Number
  ) as Float {
    var day_fraction = h.toFloat() / 24.0;

    if (m <= 2) {
      y -= 1;
      m += 12;
    }

    var a = (y.toFloat() / 100.0).toNumber();
    var b = 2 - a + (a.toFloat() / 4).toNumber();

    return (
      (365.25 * (y + 4716)).toNumber() +
      (30.6001 * (m + 1)).toNumber() +
      d.toFloat() +
      day_fraction +
      b -
      1524.5
    );
  }

  private function drawMoonPhase(dc as Dc) as Void {
    if (_showWatchHands) {
      var now = Time.now();
      if (
        currentMoonphase == null ||
        (moonphaseLastCalculated != null &&
          now.compare(moonphaseLastCalculated) > 3600)
      ) {
        // Moonphase outdated or not available
        var utcInfo = Gregorian.utcInfo(now, Time.FORMAT_SHORT);
        currentMoonphase = getMoonPhase(
          utcInfo.year,
          utcInfo.month,
          utcInfo.day,
          utcInfo.hour
        );
        moonphaseLastCalculated = now;
      }

      dc.setAntiAlias(true);

      dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
      dc.fillCircle(130, 130, 10);

      if (moonPhaseReferences != null) {
        var moonPhaseBitmap =
          moonPhaseReferences[currentMoonphase].get() as BitmapResource;
        dc.drawBitmap2(123, 123, moonPhaseBitmap, {});
      }
    }
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
