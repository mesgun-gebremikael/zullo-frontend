package com.baseflow.geolocator.location;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

import android.location.Location;
import android.os.Bundle;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;
import java.util.Map;

/** Exercises real BundleCompat dispatch on legacy and typed Android accessors. */
@RunWith(RobolectricTestRunner.class)
@Config(sdk = {24, 34})
public class LocationMapperCompatibilityTest {
  private Map<String, Object> map(Bundle extras) {
    Location location = new Location("gps");
    location.setLatitude(52.0);
    location.setLongitude(5.0);
    location.setExtras(extras);
    return LocationMapper.toHashMap(location);
  }

  @Test public void acceptsEverySupportedNumericExtraType() {
    Bundle extras = new Bundle();
    extras.putDouble(NmeaClient.VERTICAL_SPEED_EXTRA, 2.5);
    extras.putFloat(NmeaClient.VERTICAL_SPEED_ACCURACY_EXTRA, 0.25f);
    assertEquals(2.5, (Double) map(extras).get("vertical_speed"), 0.0001);
    assertEquals(0.25, (Double) map(extras).get("vertical_speed_accuracy"), 0.0001);
    extras.putInt(NmeaClient.VERTICAL_SPEED_EXTRA, -2);
    extras.putLong(NmeaClient.VERTICAL_SPEED_ACCURACY_EXTRA, 3L);
    assertEquals(-2.0, (Double) map(extras).get("vertical_speed"), 0.0001);
    assertEquals(3.0, (Double) map(extras).get("vertical_speed_accuracy"), 0.0001);
  }

  @Test public void ignoresWrongTypeAndUsesFallbackKey() {
    Bundle extras = new Bundle();
    extras.putString(NmeaClient.VERTICAL_SPEED_EXTRA, "not a measured speed");
    extras.putFloat("vertical_speed", -1.5f);
    assertEquals(-1.5, (Double) map(extras).get("vertical_speed"), 0.0001);
    assertFalse(map(extras).containsKey("vertical_speed_accuracy"));
  }

  @Test public void rejectsNonfiniteSpeedAndNegativeAccuracy() {
    Bundle extras = new Bundle();
    extras.putDouble(NmeaClient.VERTICAL_SPEED_EXTRA, Double.NaN);
    extras.putDouble(NmeaClient.VERTICAL_SPEED_ACCURACY_EXTRA, -1);
    assertFalse(map(extras).containsKey("vertical_speed"));
    assertFalse(map(extras).containsKey("vertical_speed_accuracy"));
    extras.putDouble(NmeaClient.VERTICAL_SPEED_EXTRA, Double.POSITIVE_INFINITY);
    assertFalse(map(extras).containsKey("vertical_speed"));
  }

  @Test public void emptyBundleDoesNotInventMeasurements() {
    assertFalse(map(new Bundle()).containsKey("vertical_speed"));
    assertFalse(map(new Bundle()).containsKey("vertical_speed_accuracy"));
  }
}
