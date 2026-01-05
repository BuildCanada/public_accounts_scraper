SELECT
  year,
  -- Provinces
  MAX(CASE WHEN province_territory = 'Alberta' THEN other_major_transfers END) AS "Alberta",
  MAX(CASE WHEN province_territory = 'British Columbia' THEN other_major_transfers END) AS "British Columbia",
  MAX(CASE WHEN province_territory = 'Manitoba' THEN other_major_transfers END) AS "Manitoba",
  MAX(CASE WHEN province_territory = 'New Brunswick' THEN other_major_transfers END) AS "New Brunswick",
  MAX(CASE WHEN province_territory = 'Newfoundland and Labrador' THEN other_major_transfers END) AS "Newfoundland and Labrador",
  MAX(CASE WHEN province_territory = 'Nova Scotia' THEN other_major_transfers END) AS "Nova Scotia",
  MAX(CASE WHEN province_territory = 'Ontario' THEN other_major_transfers END) AS "Ontario",
  MAX(CASE WHEN province_territory = 'Prince Edward Island' THEN other_major_transfers END) AS "Prince Edward Island",
  MAX(CASE WHEN province_territory = 'Quebec' THEN other_major_transfers END) AS "Quebec",
  MAX(CASE WHEN province_territory = 'Saskatchewan' THEN other_major_transfers END) AS "Saskatchewan",
  -- Territories
  MAX(CASE WHEN province_territory = 'Northwest Territories' THEN other_major_transfers END) AS "Northwest Territories",
  MAX(CASE WHEN province_territory = 'Nunavut' THEN other_major_transfers END) AS "Nunavut",
  MAX(CASE WHEN province_territory = 'Yukon' THEN other_major_transfers END) AS "Yukon",
  -- Special categories
  MAX(CASE WHEN province_territory = 'International' THEN other_major_transfers END) AS "International",
  MAX(CASE WHEN province_territory = 'Transfers made through the tax system' THEN other_major_transfers END) AS "Tax System",
  COALESCE(
    MAX(CASE WHEN province_territory = 'Accrual and other adjustments' THEN other_major_transfers END),
    MAX(CASE WHEN province_territory = 'Accrual and other  adjustments' THEN other_major_transfers END)
  ) AS "Accrual Adjustments"
FROM major_transfers_by_provinces_and_territories_inflation_adjusted
WHERE is_total_or_subtotal = 0
GROUP BY year
ORDER BY year;
