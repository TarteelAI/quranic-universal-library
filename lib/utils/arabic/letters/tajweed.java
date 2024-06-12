package com.atq.quranemajeedapp.org.mushaf.data;

import android.content.Context;
import android.support.v4.content.ContextCompat;
import android.text.Spannable;
import android.text.SpannableString;
import android.text.style.ForegroundColorSpan;
import com.atq.quranemajeedapp.org.mushaf.R;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class QuranArabicUtilsd {
    private static final Matcher gunnahmatcher = Pattern.compile("[ن|م]ّ").matcher("");
    private static final Matcher idhghammatcher = Pattern.compile("([نًٌٍ][ْاى]?[ۛۚۗۖۙۘ]? [نميو])|م[ْۛۚۗۖۙۘ]? م").matcher("");
    private static final Matcher idhghammatcherwihtoutgunnah = Pattern.compile("[نًٌٍ][ْاى]?[ۛۚۗۖۙۘ]? [رل]").matcher("");
    private static final Matcher ikhfamatcher = Pattern.compile("([نًٌٍ][ْاى]?[ۛۚۗۖۙۘ]? ?[صذثكجشقسدطزفتضظ])|مْ? ?ب").matcher("");
    private static final Matcher iqlabmmatcher = Pattern.compile("[ۭۢ][ْاى]?[ۛۚۗۖۙۘ]? ?ب").matcher("");
    private static final Matcher qalqalamatcher = Pattern.compile("[قطبجد](ْ|[^ه]?[^هىا]?[^هىا]$)").matcher("");

    public static Spannable getTajweed(String s, Context context) {
        Spannable text = new SpannableString(s);
        gunnahmatcher.reset(s);
        while (gunnahmatcher.find()) {
            text.setSpan(new ForegroundColorSpan(ContextCompat.getColor(context, R.color.color_ghunna)), gunnahmatcher.start(), gunnahmatcher.end() + 1, 0);
        }
        qalqalamatcher.reset(s);
        while (qalqalamatcher.find()) {
            text.setSpan(new ForegroundColorSpan(ContextCompat.getColor(context, R.color.color_qalqala)), qalqalamatcher.start(), qalqalamatcher.end(), 0);
        }
        iqlabmmatcher.reset(s);
        while (iqlabmmatcher.find()) {
            text.setSpan(new ForegroundColorSpan(ContextCompat.getColor(context, R.color.color_iqlab)), getIqlabStart(s, iqlabmmatcher.start()), iqlabmmatcher.end() + 1, 0);
        }
        idhghammatcher.reset(s);
        while (idhghammatcher.find()) {
            text.setSpan(new ForegroundColorSpan(ContextCompat.getColor(context, R.color.color_idgham)), getStart(s, idhghammatcher.start()), getEnd(s, idhghammatcher.end()), 0);
        }
        idhghammatcherwihtoutgunnah.reset(s);
        while (idhghammatcherwihtoutgunnah.find()) {
            text.setSpan(new ForegroundColorSpan(ContextCompat.getColor(context, R.color.color_idghamwo)), getStart(s, idhghammatcherwihtoutgunnah.start()), getEnd(s, idhghammatcherwihtoutgunnah.end()), 0);
        }
        ikhfamatcher.reset(s);
        while (ikhfamatcher.find()) {
            text.setSpan(new ForegroundColorSpan(ContextCompat.getColor(context, R.color.color_ikhfa)), getStart(s, ikhfamatcher.start()), getEnd(s, ikhfamatcher.end()), 0);
        }
        return text;
    }

    private static int getIqlabStart(String m, int start) {
        boolean z = true;
        boolean z2 = (m.charAt(start + -1) == 1611) | (m.charAt(start + -1) == 1612);
        if (m.charAt(start - 1) != 1613) {
            z = false;
        }
        if (!z2 && !z) {
            return start - 1;
        }
        if (m.charAt(start - 2) == 1617) {
            return start - 3;
        }
        return start - 2;
    }

    private static int getEnd(String m, int end) {
        if (m.charAt(end) == 1617) {
            return end + 2;
        }
        return end + 1;
    }

    private static int getStart(String m, int start) {
        boolean z;
        boolean z2 = true;
        if (m.charAt(start) == 1611) {
            z = true;
        } else {
            z = false;
        }
        boolean z3 = z | (m.charAt(start) == 1612);
        if (m.charAt(start) != 1613) {
            z2 = false;
        }
        if (!z3 && !z2) {
            return start;
        }
        if (m.charAt(start - 1) == 1617) {
            return start - 2;
        }
        return start - 1;
    }
}
