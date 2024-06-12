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
    qalaqah: "Qalaqah",
    ikhafa_shafawi: "Ikhafa' Shafawi - With Meem",
    ikhafa: "Ikhafa'",
    iqlab: "Iqlab",
    idgham_shafawi: "Idgham Shafawi - With Meem",
    idgham_ghunnah: "Idgham - With Ghunnah",
    idgham_wo_ghunnah: "Idgham - Without Ghunnah",
    idgham_mutajanisayn: "Idgham - Mutajanisayn",
    idgham_mutaqaribayn: "Idgham - Mutaqaribayn",
    ghunnah: "Ghunnah: 2 Vowels"
}
const TAJWEED_RULES = [
    "ham_wasl",
    "slnt",
    "laam_shamsiyah",
    "madda_normal",
    "madda_permissible",
    "madda_necessary",
    "madda_obligatory",
    "qalaqah",
    "ikhafa_shafawi",
    "ikhafa",
    "iqlab",
    "idgham_shafawi",
    "idgham_ghunnah",
    "idgham_wo_ghunnah",
    "idgham_mutajanisayn",
    "idgham_mutaqaribayn",
    "ghunnah"
]

export default class extends Controller {
    connect() {
        this.bindTajweedTooltip()
    }

    bindTajweedTooltip() {
        TAJWEED_RULES.forEach( (name, i) => {
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
