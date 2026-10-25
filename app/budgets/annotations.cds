using BudgetCockpitService as service from '../../srv/cockpit-service';

// ---------------- Budgets: list and detail page ----------------
annotate service.Budgets with @(
  UI.HeaderInfo: {
    TypeName      : 'Budget',
    TypeNamePlural: 'Budgets',
    Title         : { Value: costCenterName },
    Description   : { Value: costCenter }
  },

  UI.SelectionFields: [ companyCode, fiscalYear, responsibleUser, reviewStatus_code ],

  UI.LineItem: [
    { $Type: 'UI.DataFieldForAction', Action: 'BudgetCockpitService.EntityContainer/syncActuals',
      Label: 'Synchronize Actuals' },
    { Value: costCenter },
    { Value: costCenterName },
    { Value: responsibleUser },
    { Value: budgetAmount },
    { Value: actualAmount },
    { $Type: 'UI.DataFieldForAnnotation', Target: '@UI.DataPoint#Consumption', Label: 'Consumption' },
    { Value: alertText, Criticality: alertLevel },
    { Value: reviewStatus_code, Criticality: reviewStatus.criticality }
  ],

  UI.DataPoint #Consumption: {
    Value        : consumption,
    TargetValue  : 100,
    Visualization: #Progress,
    Criticality  : alertLevel
  },

  UI.Identification: [
    { $Type: 'UI.DataFieldForAction', Action: 'BudgetCockpitService.justify',  Label: 'Justify' },
    { $Type: 'UI.DataFieldForAction', Action: 'BudgetCockpitService.validate', Label: 'Validate' }
  ],

  UI.HeaderFacets: [
    { $Type: 'UI.ReferenceFacet', Target: '@UI.DataPoint#Consumption', Label: 'Consumption' }
  ],

  UI.FieldGroup #General: { Data: [
    { Value: costCenter }, { Value: controllingArea }, { Value: companyCode },
    { Value: fiscalYear }, { Value: responsibleUser }, { Value: lastSyncAt }
  ]},

  UI.FieldGroup #Budget: { Data: [
    { Value: budgetAmount }, { Value: actualAmount }, { Value: consumption },
    { Value: alertThreshold }, { Value: alertText, Criticality: alertLevel }
  ]},

  UI.FieldGroup #Review: { Data: [
    { Value: reviewStatus_code, Criticality: reviewStatus.criticality },
    { Value: justification }
  ]},

  UI.Facets: [
    { $Type: 'UI.ReferenceFacet', ID: 'General', Label: 'General Information', Target: '@UI.FieldGroup#General' },
    { $Type: 'UI.ReferenceFacet', ID: 'Budget',  Label: 'Budget vs Actual',    Target: '@UI.FieldGroup#Budget' },
    { $Type: 'UI.ReferenceFacet', ID: 'Review',  Label: 'Review',              Target: '@UI.FieldGroup#Review' },
    { $Type: 'UI.ReferenceFacet', ID: 'Actuals', Label: 'Actuals from S/4HANA', Target: 'items/@UI.LineItem' }
  ]
);

annotate service.Budgets with {
  reviewStatus @(
    Common.Text           : reviewStatus.name,
    Common.TextArrangement: #TextOnly,
    Common.ValueListWithFixedValues
  );
}

// ---------------- Actuals: table on the detail page ----------------
annotate service.Actuals with @(
  UI.LineItem: [
    { Value: fiscalPeriod },
    { Value: glAccount },
    { Value: glAccountName },
    { Value: amount }
  ]
);