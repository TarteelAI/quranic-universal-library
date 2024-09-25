import {Controller} from "@hotwired/stimulus"
import {Tooltip} from "bootstrap";

const TAJWEED_RULE_DESCRIPTION = {
  ham_wasl: "Hamzat ul Wasl",
  slnt: "Silent",
  laam_shamsiyah: "Lam Shamsiyyah",
  madda_normal: "Normal Prolongation: 2 Vowels",
  madda_permissible: "Permissible Prolongation: 2, 4, 6 Vowels",
  madda_necessary: "Necessary Prolongation: 6 Vowels",
  madda_obligatory: "Obligatory Prolongation: 4-5 Vowels",
  madda_obligatory_monfasel: "Madd Al-Munfasil 2, 4, or 5 Vowels",
  madda_obligatory_mottasel: "Madd Al-Muttasil 4, or 5 Vowels",
  qalaqah: "Qalaqah",
  ikhafa_shafawi: "Ikhafa' Shafawi - With Meem",
  ikhafa: "Ikhafa'",
  iqlab: "Iqlab",
  idgham_shafawi: "Idgham Shafawi - With Meem",
  idgham_ghunnah: "Idgham - With Ghunnah",
  idgham_wo_ghunnah: "Idgham - Without Ghunnah",
  idgham_mutajanisayn: "Idgham - Mutajanisayn",
  idgham_mutaqaribayn: "Idgham - Mutaqaribayn",
  ghunnah: "Ghunnah: 2 Vowels",
  izhar: "Izhaar Halqi الإظهار الحلقى",
  izhar_shafawi: "Izhar Shafawi - With Meem",
  tafkheem: 'Tafkheem(Heavy letter)'
}

export default class extends Controller {
  connect() {
    this.addTatweelBeforeDaggerAlif();
    this.bindTajweedTooltip()
  }

  addTatweelBeforeDaggerAlif(){
    /*this.element.querySelectorAll('.madda_normal').forEach((madRule, _) => {
      if(!madRule.innerText.includes('ـ')) {
        madRule.innerText = madRule.innerText.replace("ٰ", "ـٰ");
      }
    })*/

    this.element.querySelectorAll('.madda_normal').forEach((madRule) => {
      let prevLetter = this.getPreviousLetter(madRule);
      if (prevLetter && this.isJoiningLetter(prevLetter) && !madRule.innerText.includes('ـ')) {
        madRule.innerText = madRule.innerText.replace("ٰ", "ـٰ");
      }
    });
  }

  isJoiningLetter(letter) {
    const nonJoiningLetters = ['ى','و', 'ز', 'ر', 'ذ', 'د', 'ا', 'ء'];
    return !nonJoiningLetters.includes(letter);
  }

  getPreviousLetter(madRule) {
    let prevNode = madRule.previousSibling;
    if (!prevNode) return null;

    let prevText;

    // If the previous node is an element (wrapped in a div or span), get its text content
    if (prevNode.nodeType === Node.ELEMENT_NODE) {
      prevText = prevNode.innerText;
    }
    // If the previous node is a text node, get the content
    else if (prevNode.nodeType === Node.TEXT_NODE) {
      prevText = prevNode.textContent;
    }

    if (prevText) {
      // Strip diacritical marks (harakat) using a regex that matches Arabic harakat Unicode range
      let baseLetter = prevText.replace(/[\u064B-\u0652]/g, '').slice(-1);
      return baseLetter;
    }

    return null;
  }
  bindTajweedTooltip() {
    const keys = Object.keys(TAJWEED_RULE_DESCRIPTION);
    keys.forEach((name, i) => {
      this.element.querySelectorAll(`.${name}`).forEach((elem, _) => {
        new Tooltip(elem, {
          direction: "top",
          title: TAJWEED_RULE_DESCRIPTION[name],
          sanitize: false
        });
      })
    })
  }
}
