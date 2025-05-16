// utils/dateUtils.js

/**
 * Get start and end date for a given month in YYYY-MM format
 * @param {string} month - Month in YYYY-MM format (e.g., "2023-05")
 * @returns {Object} Object with startDate and endDate
 */
function getDateRangeFromMonth(month) {
  // If month is not provided, use current month
  if (!month) {
    const now = new Date()
    month = now.toISOString().substring(0, 7) // YYYY-MM format
  }

  try {
    // Validate month format
    if (!month.match(/^\d{4}-\d{2}$/)) {
      console.warn(`Invalid month format: ${month}, using current month instead`)
      const now = new Date()
      month = now.toISOString().substring(0, 7)
    }

    const year = Number.parseInt(month.substring(0, 4))
    const monthIndex = Number.parseInt(month.substring(5, 7)) - 1 // JS months are 0-indexed

    const startDate = new Date(year, monthIndex, 1)
    const endDate = new Date(year, monthIndex + 1, 0)
    endDate.setHours(23, 59, 59, 999) // End of the last day

    return {
      startDate,
      endDate,
    }
  } catch (error) {
    console.error(`Error in getDateRangeFromMonth: ${error.message}`)
    // Return current month as fallback
    const now = new Date()
    const year = now.getFullYear()
    const monthIndex = now.getMonth()

    const startDate = new Date(year, monthIndex, 1)
    const endDate = new Date(year, monthIndex + 1, 0)
    endDate.setHours(23, 59, 59, 999)

    return {
      startDate,
      endDate,
    }
  }
}

module.exports = {
  getDateRangeFromMonth,
}

