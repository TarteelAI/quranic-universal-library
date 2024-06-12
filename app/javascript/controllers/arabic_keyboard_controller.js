import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
      $(this.element).keyboard({
            autoAccept: false,
            stayOpen: true,
            layout: 'custom',
            rtl: true,
            language: ['en'],
            closeByClickEvent: false,
            enterNavigation: false,
            usePreview: true,
            visible: function () {
              setTimeout(function () {
                $('.ui-keyboard').draggable()
              }, 2000)
            },
            css: {
              input: 'form-control',
              container: 'center-block dropdown-menu',
              buttonDefault: 'btn btn-default',
              buttonHover: 'btn-primary',
              buttonAction: 'active',
              buttonDisabled: 'disabled'
            },
            customLayout: {
              'custom': [
                '\u06e4',
                '{tab} \u0636(c) \u0635 \u062b \u0642 \u0641 \u063a \u0639 \u0647 \u062e \u062d \u062c \u062f',
                '{lock} \u0634 \u0633 \u064a \u0628 \u0644 \u0627 \u062a \u0646 \u0645 \u0643 \u0637 \u0630 {enter}',
                '{shift} \u0640 \u0626 \u0621 \u0624 \u0631 \ufefb \u0649 \u0629 \u0648 \u0632 \u0638 {shift}',
                '{accept} {alt} {space} {alt} {custom}'
              ],
              'shift': [
                "ٓ(`) َ(1) ً(2) ُ(3) ٌ(4) ّ(5) ْ(6) ِ(7) ٍ(8) ء(9) ي(0) ئ(-)  ۛ(+){bksp}",
                "{tab} ك(Q) ّ(W) {empty} {empty} ث(T) ے(Y) ة(U) ى(I) {empty}  ٰ (})",
                "{lock} آ(A) ص(S) ض(D) ق(F) غ(G) ه(H) ج(J) خ(K) إ(L) : \" {enter}",
                "{shift} ذ(Z) ط(X) ظ(C) {empty} {empty} ں(N)  > < / {shift}",
                "{accept} {alt} {space}"
              ],
              'normal': [
                "ٓ(`) َ(1) ً(2) ُ(3) ٌ(4) ّ(5) ْ(6) ِ(7) ٍ(8) ء(9) ي(0) ئ(-) \u06e4",
                "{tab} ق(q) و(w) ع(e) ر(r) ت(t) ے(y) ِ(u) ي(i) ُ(o) ّ(p) ۛ([) ٰ (]) \ ",
                "{lock} ا(a) س(s) د(d) ف(f) ع(g) ح(h) ج(j) ك(k) ل(l) ؛(;) '(') {enter}",
                "{shift} ز(z) ش(x) چ(c) ث(v) ب(b) ن(n) م(m) ْ(,) \u06be(.) \u06c1(/) {shift}",
                "{cancel} {alt} {space} {accept}"
              ],
              'alt': [
                "\u0654 \u0653 \u0658 ْ  ِ  ٌ  َ  ً  ُ    \u06e4   ",
                "ٰ ء ي ئ ؤ ة إ أ آ ۛ",
                "ۢ   ۖ  ۚ  ۛ  ٌ  ّ    ۚ  ؕ   ۙ  ",
                "{alt} {space} "
              ]

            }
          }
      ).addTyping({showTyping: true}).previewKeyset()
  }
}
