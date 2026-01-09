SELECT
  year,
  -- Provinces
  MAX(CASE WHEN province_territory = 'Alberta' THEN canadawide_early_learning_and_child_care END) AS "Alberta",
  MAX(CASE WHEN province_territory = 'British Columbia' THEN canadawide_early_learning_and_child_care END) AS "British Columbia",
  MAX(CASE WHEN province_territory = 'Manitoba' THEN canadawide_early_learning_and_child_care END) AS "Manitoba",
  MAX(CASE WHEN province_territory = 'New Brunswick' THEN canadawide_early_learning_and_child_care END) AS "New Brunswick",
  MAX(CASE WHEN province_territory = 'Newfoundland and Labrador' THEN canadawide_early_learning_and_child_care END) AS "Newfoundland and Labrador",
  MAX(CASE WHEN province_territory = 'Nova Scotia' THEN canadawide_early_learning_and_child_care END) AS "Nova Scotia",
  MAX(CASE WHEN province_territory = 'Ontario' THEN canadawide_early_learning_and_child_care END) AS "Ontario",
  MAX(CASE WHEN province_territory = 'Prince Edward Island' THEN canadawide_early_learning_and_child_care END) AS "Prince Edward Island",
  MAX(CASE WHEN province_territory = 'Quebec' THEN canadawide_early_learning_and_child_care END) AS "Quebec",
  MAX(CASE WHEN province_territory = 'Saskatchewan' THEN canadawide_early_learning_and_child_care END) AS "Saskatchewan",
  -- Territories
  MAX(CASE WHEN province_territory = 'Northwest Territories' THEN canadawide_early_learning_and_child_care END) AS "Northwest Territories",
  MAX(CASE WHEN province_territory = 'Nunavut' THEN canadawide_early_learning_and_child_care END) AS "Nunavut",
  MAX(CASE WHEN province_territory = 'Yukon' THEN canadawide_early_learning_and_child_care END) AS "Yukon",
  -- Special categories
  MAX(CASE WHEN province_territory = 'International' THEN canadawide_early_learning_and_child_care END) AS "International",
  MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN canadawide_early_learning_and_child_care END) AS "Tax System",
  COALESCE(
    MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN canadawide_early_learning_and_child_care END),
    MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN canadawide_early_learning_and_child_care END)
  ) AS "Accrual Adjustments"
FROM major_transfers_by_provinces_and_territories_inflation_adjusted
WHERE is_total_or_subtotal = 0
   OR province_territory IN ('Accrual and other adjustments', 'Accrual and other  adjustments')
GROUP BY year
ORDER BY year;
