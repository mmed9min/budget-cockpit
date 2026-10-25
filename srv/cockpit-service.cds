using budget.cockpit as db from '../db/schema';

@path    : 'budget-cockpit'
@requires: 'authenticated-user'
service BudgetCockpitService {

  @readonly
  @restrict: [
    { grant: 'READ', to: 'BudgetController' },
    { grant: 'READ', to: 'CostCenterOwner', where: 'responsibleUser = $user' }
  ]
  entity Budgets as projection on db.Budgets;

  @readonly
  @restrict: [{ grant: 'READ', to: ['BudgetController', 'CostCenterOwner'] }]
  entity ActualLineItems as projection on db.ActualLineItems;

  @readonly
  entity ReviewStatuses as projection on db.ReviewStatuses;
}