const cds = require('@sap/cds')

const LEADING_LEDGER = '0L'

module.exports = class BudgetCockpitService extends cds.ApplicationService {
  init () {
    const { Budgets, Actuals } = cds.entities('budget.cockpit')

    this.on('syncActuals', async req => {
      const { fiscalYear } = req.data
      if (!/^\d{4}$/.test(fiscalYear ?? '')) {
        return req.error(400, 'Fiscal year must have 4 digits')
      }

      // 1. Which cost centers have a budget this year?
      const budgets = await SELECT.from(Budgets)
        .columns('ID', 'companyCode', 'costCenter')
        .where({ fiscalYear })
      if (!budgets.length) {
        return req.error(404, `No budgets defined for fiscal year ${fiscalYear}`)
      }
      const companyCodes = [...new Set(budgets.map(b => b.companyCode))]
      const costCenters  = [...new Set(budgets.map(b => b.costCenter))]

      // 2. Read the actuals from S/4HANA (mocked locally, real API on BTP)
      const s4 = await cds.connect.to('API_JOURNALENTRYITEMBASIC_SRV')
      const rows = await s4.run(
        SELECT.from(s4.entities.A_JournalEntryItemBasic)
          .columns('CompanyCode', 'LedgerFiscalYear', 'FiscalPeriod', 'CostCenter',
                   'GLAccount', 'GLAccountName',
                   'AmountInCompanyCodeCurrency', 'CompanyCodeCurrency')
          .where({
            LedgerFiscalYear: fiscalYear,
            Ledger: LEADING_LEDGER,
            CompanyCode: { in: companyCodes },
            CostCenter: { in: costCenters }
          })
      )

      // 3. Map S/4HANA fields to our model
      const actuals = rows.map(r => ({
        companyCode:   r.CompanyCode,
        fiscalYear:    r.LedgerFiscalYear,
        fiscalPeriod:  r.FiscalPeriod,
        costCenter:    r.CostCenter,
        glAccount:     r.GLAccount,
        glAccountName: r.GLAccountName,
        amount:        Number(r.AmountInCompanyCodeCurrency),
        currency_code: r.CompanyCodeCurrency
      }))

      // 4. Replace the previous copy for this year
      await DELETE.from(Actuals).where({ fiscalYear, costCenter: { in: costCenters } })
      if (actuals.length) await INSERT.into(Actuals).entries(actuals)

      // 5. Update the actual amount of each budget
      const totals = {}
      for (const a of actuals) {
        const key = `${a.companyCode}|${a.costCenter}`
        totals[key] = (totals[key] ?? 0) + a.amount
      }
      const now = new Date().toISOString()
      for (const b of budgets) {
        const actual = Math.round((totals[`${b.companyCode}|${b.costCenter}`] ?? 0) * 100) / 100
        await UPDATE(Budgets, b.ID).with({ actualAmount: actual, lastSyncAt: now })
      }

      req.info(`${budgets.length} budgets updated from ${actuals.length} S/4HANA records`)
      return { budgets: budgets.length, actuals: actuals.length }
    })
        // --- Owner justifies an overrun or a reached threshold ---
    this.on('justify', 'Budgets', async req => {
      const { ID } = req.params[0]
      const budget = await SELECT.one.from(Budgets, ID)
        .columns('ID', 'alertLevel', 'reviewStatus_code')
      if (!budget) return req.error(404, 'Budget not found')
      if (budget.alertLevel === 3) {
        return req.error(400, 'This cost center is within budget, no justification is needed')
      }
      if (budget.reviewStatus_code !== 'O') {
        return req.error(409, 'This budget has already been justified')
      }
      const text = req.data.text?.trim()
      if (!text) return req.error(400, 'Enter a justification')

      await UPDATE(Budgets, ID).with({ justification: text, reviewStatus_code: 'J' })
      return SELECT.one.from(this.entities.Budgets, ID)
    })

    // --- Controller validates a justified budget ---
    this.on('validate', 'Budgets', async req => {
      const { ID } = req.params[0]
      const budget = await SELECT.one.from(Budgets, ID).columns('ID', 'reviewStatus_code')
      if (!budget) return req.error(404, 'Budget not found')
      if (budget.reviewStatus_code !== 'J') {
        return req.error(409, 'Only justified budgets can be validated')
      }

      await UPDATE(Budgets, ID).with({ reviewStatus_code: 'V' })
      return SELECT.one.from(this.entities.Budgets, ID)
    })

    return super.init()
  }
}