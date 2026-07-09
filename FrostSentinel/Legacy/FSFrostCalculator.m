//
//  FSFrostCalculator.m
//  FrostSentinel
//
//  See FSFrostCalculator.h for why this class is Objective-C on purpose.
//

#import "FSFrostCalculator.h"

static const double FSDefaultWatchMarginCelsius = 3.0;
static const double FSDefaultHardFreezeMarginCelsius = 3.0;
static const double FSDefaultHeatWatchMarginCelsius = 3.0;
static const double FSDefaultScorchMarginCelsius = 4.0;

@implementation FSFrostCalculator

- (instancetype)init {
    return [self initWithWatchMarginCelsius:FSDefaultWatchMarginCelsius
                    hardFreezeMarginCelsius:FSDefaultHardFreezeMarginCelsius
                     heatWatchMarginCelsius:FSDefaultHeatWatchMarginCelsius
                        scorchMarginCelsius:FSDefaultScorchMarginCelsius];
}

- (instancetype)initWithWatchMarginCelsius:(double)watchMargin
                   hardFreezeMarginCelsius:(double)hardFreezeMargin {
    return [self initWithWatchMarginCelsius:watchMargin
                    hardFreezeMarginCelsius:hardFreezeMargin
                     heatWatchMarginCelsius:FSDefaultHeatWatchMarginCelsius
                        scorchMarginCelsius:FSDefaultScorchMarginCelsius];
}

- (instancetype)initWithWatchMarginCelsius:(double)watchMargin
                   hardFreezeMarginCelsius:(double)hardFreezeMargin
                    heatWatchMarginCelsius:(double)heatWatchMargin
                       scorchMarginCelsius:(double)scorchMargin {
    self = [super init];
    if (self) {
        _watchMarginCelsius = watchMargin;
        _hardFreezeMarginCelsius = hardFreezeMargin;
        _heatWatchMarginCelsius = heatWatchMargin;
        _scorchMarginCelsius = scorchMargin;
    }
    return self;
}

- (double)marginForForecastMinCelsius:(double)forecastMinCelsius
                     toleranceCelsius:(double)toleranceCelsius {
    return forecastMinCelsius - toleranceCelsius;
}

- (FSFrostRisk)riskForForecastMinCelsius:(double)forecastMinCelsius
                        toleranceCelsius:(double)toleranceCelsius {
    double margin = [self marginForForecastMinCelsius:forecastMinCelsius
                                     toleranceCelsius:toleranceCelsius];

    if (margin > self.watchMarginCelsius) {
        return FSFrostRiskNone;
    }
    if (margin > 0.0) {
        return FSFrostRiskWatch;
    }
    if (margin > -self.hardFreezeMarginCelsius) {
        return FSFrostRiskFrost;
    }
    return FSFrostRiskHardFreeze;
}

- (NSString *)adviceForRisk:(FSFrostRisk)risk plantName:(NSString *)plantName {
    switch (risk) {
        case FSFrostRiskNone:
            return [NSString stringWithFormat:@"%@ is fine tonight.", plantName];
        case FSFrostRiskWatch:
            return [NSString stringWithFormat:@"Keep an eye on %@ — it's close to its limit tonight.", plantName];
        case FSFrostRiskFrost:
            return [NSString stringWithFormat:@"Cover %@ tonight.", plantName];
        case FSFrostRiskHardFreeze:
            return [NSString stringWithFormat:@"Bring %@ inside if you can — covering may not be enough.", plantName];
    }
    return [NSString stringWithFormat:@"%@ needs a look.", plantName];
}

// MARK: - Heat

- (double)marginForForecastMaxCelsius:(double)forecastMaxCelsius
                 heatToleranceCelsius:(double)heatToleranceCelsius {
    return heatToleranceCelsius - forecastMaxCelsius;
}

- (FSHeatRisk)heatRiskForForecastMaxCelsius:(double)forecastMaxCelsius
                       heatToleranceCelsius:(double)heatToleranceCelsius {
    double margin = [self marginForForecastMaxCelsius:forecastMaxCelsius
                                  heatToleranceCelsius:heatToleranceCelsius];

    if (margin > self.heatWatchMarginCelsius) {
        return FSHeatRiskNone;
    }
    if (margin > 0.0) {
        return FSHeatRiskWatch;
    }
    if (margin > -self.scorchMarginCelsius) {
        return FSHeatRiskHeat;
    }
    return FSHeatRiskScorch;
}

- (NSString *)adviceForHeatRisk:(FSHeatRisk)risk plantName:(NSString *)plantName {
    switch (risk) {
        case FSHeatRiskNone:
            return [NSString stringWithFormat:@"%@ can handle tomorrow.", plantName];
        case FSHeatRiskWatch:
            return [NSString stringWithFormat:@"Tomorrow runs close to %@'s limit — a drink tonight wouldn't hurt.", plantName];
        case FSHeatRiskHeat:
            return [NSString stringWithFormat:@"Water %@ tonight — tomorrow will be hotter than it likes.", plantName];
        case FSHeatRiskScorch:
            return [NSString stringWithFormat:@"Water %@ deeply tonight and shade it tomorrow — watering alone may not be enough.", plantName];
    }
    return [NSString stringWithFormat:@"%@ needs a look.", plantName];
}

@end
