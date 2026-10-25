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
  entity Actuals as projection on db.Actuals;

  @readonly
  entity ReviewStatuses as projection on db.ReviewStatuses;

  type SyncResult {
    budgets : Integer;
    actuals : Integer;
  }

  /** Replicates actuals from S/4HANA for a fiscal year */
  @requires: 'BudgetController'
  action syncActuals(fiscalYear : String(4)) returns SyncResult;
}