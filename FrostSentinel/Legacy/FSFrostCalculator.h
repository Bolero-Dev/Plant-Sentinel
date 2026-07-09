//
//  FSFrostCalculator.h
//  PlantSentinel (formerly FrostSentinel)
//
//  Temperature-risk classification, written in Objective-C.
//
//  Why Objective-C? Deliberately. Horticultural and agricultural calculation
//  libraries in the real world are frequently legacy code, and contract work
//  means maintaining and bridging code like this rather than rewriting it.
//  This class demonstrates Swift/Objective-C interop: NS_ENUMs bridged into
//  Swift, nullability annotations, and a small, well-documented legacy surface
//  consumed by modern async Swift.
//
//  History note (kept on purpose): this class began life as a frost-only
//  calculator. When the app became multi-season, heat classification was
//  ADDED rather than rewriting the class — extending a legacy surface without
//  breaking its existing callers is exactly how this goes in production. The
//  class name stays FSFrostCalculator for the same reason real legacy names
//  outlive their accuracy.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The frost risk for a single plant on a single night.
typedef NS_ENUM(NSInteger, FSFrostRisk) {
    /// Forecast minimum is comfortably above the plant's cold tolerance.
    FSFrostRiskNone = 0,
    /// Forecast minimum is within the watch margin of the plant's tolerance.
    FSFrostRiskWatch = 1,
    /// Forecast minimum is at or below the plant's tolerance. Cover it.
    FSFrostRiskFrost = 2,
    /// Forecast minimum is far below tolerance. Covering may not be enough.
    FSFrostRiskHardFreeze = 3,
};

/// The heat risk for a single plant on the following day.
/// Advice is deliberately evening-framed ("water tonight") because watering
/// the night before a hot day beats watering during it.
typedef NS_ENUM(NSInteger, FSHeatRisk) {
    /// Forecast maximum is comfortably below the plant's heat tolerance.
    FSHeatRiskNone = 0,
    /// Forecast maximum is within the watch margin of the plant's tolerance.
    FSHeatRiskWatch = 1,
    /// Forecast maximum is at or above the plant's tolerance. Water tonight.
    FSHeatRiskHeat = 2,
    /// Forecast maximum is far above tolerance. Water deeply and shade it.
    FSHeatRiskScorch = 3,
};

@interface FSFrostCalculator : NSObject

/// The margin (in °C) above a plant's tolerance at which we start warning.
/// Forecasts are imprecise; a night forecast within this margin deserves
/// attention even though it is nominally "safe".
@property (nonatomic, readonly) double watchMarginCelsius;

/// The margin (in °C) below a plant's tolerance at which covering the plant
/// is unlikely to be enough protection.
@property (nonatomic, readonly) double hardFreezeMarginCelsius;

/// The margin (in °C) below a plant's heat tolerance at which we start
/// warning about the next day's high.
@property (nonatomic, readonly) double heatWatchMarginCelsius;

/// The margin (in °C) above a plant's heat tolerance at which watering alone
/// is unlikely to be enough — the plant also needs shade.
@property (nonatomic, readonly) double scorchMarginCelsius;

- (instancetype)init;

/// Original frost-only initializer, kept so existing callers keep compiling.
/// Heat margins fall back to their defaults.
- (instancetype)initWithWatchMarginCelsius:(double)watchMargin
                   hardFreezeMarginCelsius:(double)hardFreezeMargin;

- (instancetype)initWithWatchMarginCelsius:(double)watchMargin
                   hardFreezeMarginCelsius:(double)hardFreezeMargin
                    heatWatchMarginCelsius:(double)heatWatchMargin
                       scorchMarginCelsius:(double)scorchMargin NS_DESIGNATED_INITIALIZER;

/// Classifies the risk for one plant on one night.
///
/// @param forecastMinCelsius The forecast overnight minimum temperature.
/// @param toleranceCelsius   The lowest temperature the plant tolerates unprotected.
- (FSFrostRisk)riskForForecastMinCelsius:(double)forecastMinCelsius
                        toleranceCelsius:(double)toleranceCelsius;

/// A short, calm, user-facing recommendation for a risk level.
/// The tone is deliberate: no alarm, just what to do.
- (NSString *)adviceForRisk:(FSFrostRisk)risk plantName:(NSString *)plantName;

/// The margin, in °C, between the forecast and the plant's tolerance.
/// Positive means safe headroom; negative means the forecast dips below tolerance.
- (double)marginForForecastMinCelsius:(double)forecastMinCelsius
                     toleranceCelsius:(double)toleranceCelsius;

/// Classifies the heat risk for one plant on one day.
///
/// @param forecastMaxCelsius   The forecast daytime maximum temperature.
/// @param heatToleranceCelsius The highest temperature the plant tolerates
///                             without extra water or shade.
- (FSHeatRisk)heatRiskForForecastMaxCelsius:(double)forecastMaxCelsius
                       heatToleranceCelsius:(double)heatToleranceCelsius;

/// A short, calm, user-facing recommendation for a heat-risk level.
/// Framed for the evening before: watering tonight beats watering at noon.
///
/// NS_SWIFT_NAME because Swift's "omit needless words" import would strip
/// "HeatRisk" (it matches the argument type) and collide with the frost
/// version as advice(for:plantName:) — making every `.none` ambiguous.
- (NSString *)adviceForHeatRisk:(FSHeatRisk)risk
                      plantName:(NSString *)plantName
    NS_SWIFT_NAME(advice(forHeatRisk:plantName:));

/// The margin, in °C, between the plant's heat tolerance and the forecast max.
/// Positive means safe headroom; negative means the forecast climbs above tolerance.
- (double)marginForForecastMaxCelsius:(double)forecastMaxCelsius
                 heatToleranceCelsius:(double)heatToleranceCelsius;

@end

NS_ASSUME_NONNULL_END
