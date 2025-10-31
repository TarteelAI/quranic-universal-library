import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["searchInput", "tableRow"]

  search() {
    const searchTerm = this.searchInputTarget.value.trim().toLowerCase()
    
    this.tableRowTargets.forEach(row => {
      const pageNumber = row.dataset.pageNumber
      const firstAyah = row.dataset.firstAyah || ""
      const lastAyah = row.dataset.lastAyah || ""
      
      if (searchTerm === "") {
        row.style.display = ""
        return
      }
      
      if (pageNumber.includes(searchTerm)) {
        row.style.display = ""
        return
      }
      
      if (firstAyah.toLowerCase().includes(searchTerm) || 
          lastAyah.toLowerCase().includes(searchTerm)) {
        row.style.display = ""
        return
      }
      
      if (searchTerm.includes(":")) {
        const [surah, ayah] = searchTerm.split(":").map(n => parseInt(n))
        
        if (!isNaN(surah) && !isNaN(ayah)) {
          const [firstSurah, firstAyahNum] = firstAyah.split(":").map(n => parseInt(n))
          const [lastSurah, lastAyahNum] = lastAyah.split(":").map(n => parseInt(n))
          
          if (this.isAyahInRange(surah, ayah, firstSurah, firstAyahNum, lastSurah, lastAyahNum)) {
            row.style.display = ""
            return
          }
        }
      }
      
      row.style.display = "none"
    })
  }
  
  isAyahInRange(surah, ayah, firstSurah, firstAyah, lastSurah, lastAyah) {
    if (surah === firstSurah && surah === lastSurah) {
      return ayah >= firstAyah && ayah <= lastAyah
    }
    
    if (surah === firstSurah) {
      return ayah >= firstAyah
    }
    
    if (surah === lastSurah) {
      return ayah <= lastAyah
    }
    
    if (surah > firstSurah && surah < lastSurah) {
      return true
    }
    
    return false
  }
}

