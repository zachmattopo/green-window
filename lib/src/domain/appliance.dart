/// Appliance presets and their assumed run times (PRD §7).
enum Appliance {
  washingMachine('Washing machine', Duration(hours: 2)),
  dishwasher('Dishwasher', Duration(hours: 3)),
  tumbleDryer('Tumble dryer', Duration(hours: 1, minutes: 30)),
  evCharge('EV charge (top-up)', Duration(hours: 4));

  const Appliance(this.label, this.runTime);

  final String label;
  final Duration runTime;
}
