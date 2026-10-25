namespace budget.cockpit;

using {
  cuid,
  managed,
  Currency,
  sap.common.CodeList
} from '@sap/cds/common';

/**
 * One budget per cost center and fiscal year.
 * Budgets live in the extension; actuals come from S/4HANA.
 */
@assert.unique: { budgetPerYear: [companyCode, costCenter, fiscalYear] }
entity Budgets : cuid, managed {
  @title: 'Cost Center'       @mandatory
  costCenter      : String(10);

  @title: 'Controlling Area'  @mandatory
  controllingArea : String(4);

  @title: 'Company Code'      @mandatory
  companyCode     : String(4);

  @title: 'Fiscal Year'       @mandatory
  fiscalYear      : String(4);

  @title: 'Cost Center Name'
  costCenterName  : String(40);

  @title: 'Owner'
  responsibleUser : String(255);

  @title: 'Budget'  @mandatory  @Measures.ISOCurrency: currency_code
  budgetAmount    : Decimal(15, 2);

  @mandatory
  currency        : Currency;

  @title: 'Alert Threshold (%)'
  alertThreshold  : Decimal(5, 2) default 90;

  @title: 'Actual'  @Measures.ISOCurrency: currency_code
  actualAmount    : Decimal(15, 2) default 0;

  @title: 'Last Synchronization'
  lastSyncAt      : Timestamp;

  @title: 'Review'
  reviewStatus    : Association to ReviewStatuses default 'O';

  @title: 'Justification'  @UI.MultiLineText
  justification   : String(1000);

  // ---- Calculated on read (never stored) ----

  @title: 'Consumption (%)'
  consumption : Decimal(9, 2) = case
    when budgetAmount > 0 then actualAmount * 100 / budgetAmount
    else 0
  end;

  // 1 = overrun (red), 2 = threshold reached (orange), 3 = normal (green)
  @title: 'Alert Level'
  alertLevel : Integer = case
    when actualAmount > budgetAmount                          then 1
    when actualAmount * 100 >= budgetAmount * alertThreshold  then 2
    else 3
  end;

  @title: 'Alert'
  alertText : String(20) = case
    when actualAmount > budgetAmount                          then 'Overrun'
    when actualAmount * 100 >= budgetAmount * alertThreshold  then 'Threshold reached'
    else 'Normal'
  end;

  // Navigation to the replicated S/4HANA line items
  items : Association to many ActualLineItems
            on  items.companyCode = companyCode
            and items.costCenter  = costCenter
            and items.fiscalYear  = fiscalYear;
}

/**
 * Journal entry line items replicated from S/4HANA
 * (API_JOURNALENTRYITEMBASIC_SRV, leading ledger only).
 */
entity ActualLineItems : cuid {
  @title: 'Company Code'   companyCode        : String(4);
  @title: 'Fiscal Year'    fiscalYear         : String(4);
  @title: 'Journal Entry'  accountingDocument : String(10);
  @title: 'Line Item'      ledgerGLLineItem   : String(6);
  @title: 'Cost Center'    costCenter         : String(10);
  @title: 'G/L Account'    glAccount          : String(10);
  @title: 'Posting Date'   postingDate        : Date;
  @title: 'Text'           itemText           : String(50);

  @title: 'Amount'  @Measures.ISOCurrency: currency_code
  amount   : Decimal(15, 2);

  currency : Currency;
}

/** O = Open, J = Justified, V = Validated */
entity ReviewStatuses : CodeList {
  @title: 'Review'
  key code        : String(1);
      criticality : Integer;
}