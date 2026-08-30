import '../models/itinerary.dart';

class BudgetBreakdown {
  final double transportCost;
  final double hotelCost;
  final double foodCost;
  final double entryFeesCost;

  BudgetBreakdown({
    required this.transportCost,
    required this.hotelCost,
    required this.foodCost,
    required this.entryFeesCost,
  });

  double get total => transportCost + hotelCost + foodCost + entryFeesCost;
}

class BudgetService {
  /// Calculates cost breakdown grouped by activity type
  BudgetBreakdown calculateBreakdown(FullItinerary itinerary) {
    double transport = 0.0;
    double hotel = 0.0;
    double food = 0.0;
    double entryFees = 0.0;

    for (var day in itinerary.days) {
      for (var activity in day.activities) {
        switch (activity.type) {
          case ActivityType.transport:
            transport += activity.cost;
            break;
          case ActivityType.hotel:
            hotel += activity.cost;
            break;
          case ActivityType.restaurant:
            food += activity.cost;
            break;
          case ActivityType.spot:
            entryFees += activity.cost;
            break;
        }
      }
    }

    return BudgetBreakdown(
      transportCost: transport,
      hotelCost: hotel,
      foodCost: food,
      entryFeesCost: entryFees,
    );
  }

  /// Verifies if total trip expenses exceed budget
  bool isOverBudget(FullItinerary itinerary, double maxBudget) {
    return itinerary.totalTripCost > maxBudget;
  }

  /// Returns remaining allocated budget amount
  double remainingBudget(FullItinerary itinerary, double maxBudget) {
    return maxBudget - itinerary.totalTripCost;
  }
}