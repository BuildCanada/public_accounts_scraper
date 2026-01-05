SELECT
  year,
  -- Provinces
  MAX(CASE WHEN province_territory = 'Alberta' THEN quebec_abatement END) AS "Alberta",
  MAX(CASE WHEN province_territory = 'British Columbia' THEN quebec_abatement END) AS "British Columbia",
  MAX(CASE WHEN province_territory = 'Manitoba' THEN quebec_abatement END) AS "Manitoba",
  MAX(CASE WHEN province_territory = 'New Brunswick' THEN quebec_abatement END) AS "New Brunswick",
  MAX(CASE WHEN province_territory = 'Newfoundland and Labrador' THEN quebec_abatement END) AS "Newfoundland and Labrador",
  MAX(CASE WHEN province_territory = 'Nova Scotia' THEN quebec_abatement END) AS "Nova Scotia",
  MAX(CASE WHEN province_territory = 'Ontario' THEN quebec_abatement END) AS "Ontario",
  MAX(CASE WHEN province_territory = 'Prince Edward Island' THEN quebec_abatement END) AS "Prince Edward Island",
  MAX(CASE WHEN province_territory = 'Quebec' THEN quebec_abatement END) AS "Quebec",
  MAX(CASE WHEN province_territory = 'Saskatchewan' THEN quebec_abatement END) AS "Saskatchewan",
  -- Territories
  MAX(CASE WHEN province_territory = 'Northwest Territories' THEN quebec_abatement END) AS "Northwest Territories",
  MAX(CASE WHEN province_territory = 'Nunavut' THEN quebec_abatement END) AS "Nunavut",
  MAX(CASE WHEN province_territory = 'Yukon' THEN quebec_abatement END) AS "Yukon",
  -- Special categories
  MAX(CASE WHEN province_territory = 'International' THEN quebec_abatement END) AS "International",
  MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN quebec_abatement END) AS "Tax System",
  COALESCE(
    MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN quebec_abatement END),
    MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN quebec_abatement END)
  ) AS "Accrual Adjustments"
FROM major_transfers_by_provinces_and_territories_inflation_adjusted
WHERE is_total_or_subtotal = 0
GROUP BY year
ORDER BY year;
