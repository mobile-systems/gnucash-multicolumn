;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; current-vs-average.scm : Show comparison between current and average account values or transactions
;; in account(s) in multiple periods
;;
;; Based on transaction.scm originally by Robert Merkel <rgmerk@mira.net>
;; Contributions by Bryan Larsen <blarsen@ada-works.com>,
;;  Christian Stimming <stimming@tuhh.de>, Michael T. Garrison Stuber,
;;  Tomas Pospisek <tpo_deb@sourcepole.ch> with a lot of help from "warlord",
;;  D.B.Doughty <dbdoughty at gmail.com>
;;  Comparison report developed by D.B.Doughty <dbdoughty at gmail.com>


;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2 of
;; the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, contact:
;;
;; Free Software Foundation           Voice:  +1-617-542-5942
;; 51 Franklin Street, Fifth Floor    Fax:    +1-617-542-2652
;; Boston, MA  02110-1301,  USA       gnu@gnu.org
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; potential items to-do?
; 1. create delta table col1 = base col2 on = delta (base - period)


(define-module (gnucash report standard-reports current-vs-average))

(use-modules (gnucash main)) ;; FIXME: delete after we finish modularizing.
(use-modules (srfi srfi-1))
(use-modules (gnucash gnc-module))
(use-modules (gnucash gettext))

(use-modules (gnucash printf))
;

;;following line is step 1 of 4 needed to add gnctimeperiod-utilities
(use-modules (gnucash gnctimeperiod-utilities))

;;following line is needed for consolidating/ compostite transactions
;; since gnc:register-guid is not being exported in  report-system.scm for html-utilities.scm
(gnc:module-load "gnucash/html" 0)

(gnc:module-load "gnucash/report/report-system" 0)

(define-macro (addto! alist element)
  `(set! ,alist (cons ,element ,alist)))

;; Define the strings here to avoid typos and make changes easier.
(define reportname (N_ "Current versus Average Report"))
(define pagename-accounts (N_ "Accounts"))
(define pagename-sorting (N_ "Sorting"))
(define pagename-general (N_ "General"))
(define pagename-display (N_ "Display"))
(define optname-prime-sortkey (N_ "Primary Key"))
(define optname-prime-subtotal (N_ "Primary Subtotal"))
(define optname-prime-date-subtotal (N_ "Primary Subtotal for Date Key"))
(define optname-sec-sortkey (N_ "Secondary Key"))
(define optname-sec-subtotal (N_ "Secondary Subtotal"))
(define optname-sec-date-subtotal (N_ "Secondary Subtotal for Date Key"))
(define optname-void-transactions (N_ "Void Transactions"))
(define optname-table-export (N_ "Table for Exporting"))
(define optname-common-currency (N_ "Common Currency"))
(define optname-currency (N_ "Report's currency"))
(define def:grand-total-style "grand-total")
(define def:normal-row-style "normal-row")
(define def:alternate-row-style "alternate-row")
(define def:primary-subtotal-style "primary-subheading")
(define def:secondary-subtotal-style "secondary-subheading")

;; added for find
(define optname-find-text? (N_ "Find Text"))
(define optname-find1-field (N_ "Search"))
(define optname-find1-text   (N_ "finding the text"))
(define optname-find2-operand (N_ "Search for entries containing above string "))
(define optname-find2-field (N_ "Search for 2nd string in "))
(define optname-find2-text (N_ "2nd string"))
(define optname-find-min (N_ "Find minimum amount"))
(define optname-find-max (N_ "Find maximum ammount"))

(define optname-days (N_ "Days"))

(define text-containing ", containing " )
(define text-and " and ")
(define text-or " or ")
(define text-but-not " but not ")
(define text-minimum ", Minimum ")
(define text-maximum ", Maximum ")

;; added for consolidating
(define consolidated-text "Consolidated")
(define optname-consolidate-case-sensitive  (N_ "--  make consolidation case-sensitive"))


(define optname-descript-titlecase (N_ "Titlecase the first chracter in each word in description"))

(define 4weeks "4 weeks")
(define 8weeks "8 weeks")
(define 12weeks "12 weeks")
(define 13weeks "13 weeks")
(define 26weeks "26 weeks")
(define 52weeks "52 weeks")
(define 3months "3 months")
(define 4months "4 months")
(define 6months "6 months")
(define 9months "9 months")
(define 12months "12 months")
(define 18months "18 months")
(define 24months "24 months")

;; add for averaging
(define show-average? #t)

;; add for scaling
(define scaling-text "Note: amount and balance have been scaled.")

;; added for flagging imbalances when account name is primary key
(define optname-show-imbalance
  (N_ "Note any imbalance"))
(define opthelp-show-imbalance
  (N_ "Make a footnote if there is an imbalance when account name or account code is selected as the primary key and find not used"))

(define text-note-account " Note - account   ")
(define text-changed-in-value " in the base period  changed in value by ")
(define text-dash (_ "-")) ; printed to indicate imbalance was checked for

;; for find
(define list-findchoices
   (list (list->vector
             (list 'description
                   (N_ "description  ")
                   (N_ "search descriptions or transactions for the text - note a blank is added at start and end of description")))
            (list->vector
             (list 'account-name
                   (N_ "account name")
                   (N_ "search full account name ")))
            (list->vector
             (list 'account-code
                   (N_ "account code")
                   (N_ "search account code")))
            (list->vector
             (list 'memo
                   (N_ "memo    ")
                   (N_ "Search only memo field")))
            (list->vector
             (list 'notes
                   (N_ "notes    ")
                   (N_ "search only notes")))
            (list->vector
             (list 'memo/notes
                   (N_ "memo/notes ")
                   (N_ "search both memo and notes")))
            (list->vector
             (list 'number
                   (N_ "check number ")
                   (N_ "search check number and transaction number field")))
            (list->vector
             (list 'date
                   (N_ "date    ")
                   (N_  "search date ( a space has been added in front date and after date) ")))
            (list->vector
             (list 'reconciled-date
                   (N_ "reconciled date ")
                   (N_ "search reconciled date ( a space has been added in front of and after reconciled date)")))
            (list->vector
             (list 'reconcile
                   (N_ "reconcile ")
                   (N_ "search reconcile field (y,n,c,f) (a space has been added in front of and after reconcile character)")))
            (list->vector
             (list 'any
                   (N_ "any    ")
                   (N_ "search description and account-name and account-code and memo and notes ")))
           )
)

(define list-find2-operands
   (list (list->vector
             (list 'none
                   (N_ "    ONLY                            " )
                   (N_ "do not look for a second string of text")))
            (list->vector
             (list 'and
                   (N_ "and the 2nd string ")
                   (N_ "the transaction also must include the second text string")))
            (list->vector
             (list 'or
                   (N_ "or the 2nd string")
                   (N_ "search for either of the two text strings ")))
            (list->vector
             (list 'not
                   (N_ "but exclude entries with 2nd string")
                   (N_ "Search transactions that do not include the second text string")))
           )
)

;; this is step 2 of 4
;; needed for gnctimeperiod-utilities
;; define all option's names so that they are properly defined
;; in *one* place.
;; can change following text for local language

;; following value may need to be changed
(define the_tab pagename-general)

(define text-whichperiod "Select Period")
(define text-customdates "Custom Dates")
(define custom-from-date (N_ "Custom_Start Date"))
(define custom-to-date (N_ "Custom_End Date"))
(define text-pick-year "Year for Specified Pick")
(define text-period "Specified Period")
(define text-last "Specified Last")
(define text-month "Specified Month")

(define text-average "Average period")
(define text-exclude-average "Do not include last period in average")
(define text-number-days "  Number of Days:")

; for compare
(define pagename-compare (N_ "Compare"))
(define optname-compare? (N_ "Compare periods?"))
(define optname-no-base?  (N_ "Do not show base period, only comparison periods"))
(define optname-scale-automatically? (N_ "Ignore other scaling and"))
(define optname-scale-to (N_ "scale to"))
(define text-whichcompareperiod "Select Comparison Period")
(define text-compare-divide   "divide period into")

(define optname-show-average?  (N_ "Show average of compare periods"))

(define splits '())

(define gnc:list-datechoices
   (list (list->vector
             (list 'customdates
                   (N_ text-customdates)
                   (N_ "use selected dates and ignore specific choices")))
            (list->vector
             (list 'period
                   (N_ text-period)
                   (N_ "which period to use")))
            (list->vector
             (list 'last
                   (N_ text-last)
                   (N_ "when to use")))
            (list->vector
             (list 'month
                   (N_ text-month)
                   (N_ "use specific month")))
           )
)

(define gnc:list-datechoices-avg
   (list (list->vector
             (list 'customdates
                   (N_ text-customdates)
                   (N_ "use selected dates and ignore specific choices")))
            (list->vector
             (list 'period
                   (N_ text-period)
                   (N_ "which period to use")))
            (list->vector
             (list 'last
                   (N_ text-last)
                   (N_ "when to use")))
            (list->vector
             (list 'month
                   (N_ text-month)
                   (N_ "use specific month")))
            (list->vector
             (list 'average
                   (N_ text-average)
                   (N_ "Use time period from average list of choices")))
           )
)
(define gnc:list-average
    (list (list->vector
             (list '4weeks
                   (N_ 4weeks)
                   (N_ "4 weeks")))
            (list->vector
             (list '8weeks
                   (N_ 8weeks)
                   (N_ "8 weeks")))
            (list->vector
             (list '12weeks
                   (N_ 12weeks)
                   (N_ "12 weeks")))
            (list->vector
             (list '13weeks
                   (N_ 13weeks)
                   (N_ "13 weeks")))
            (list->vector
             (list '26weeks
                   (N_ 26weeks)
                   (N_ "26 weeks")))
            (list->vector
             (list '52weeks
                   (N_ 52weeks)
                   (N_ "52 weeks")))
            (list->vector
             (list '3months
                   (N_ 3months)
                   (N_ "3 months")))
            (list->vector
             (list '4months
                   (N_ 4months)
                   (N_ "4 months")))
            (list->vector
             (list '6months
                   (N_ 6months)
                   (N_ "6 months")))
            (list->vector
             (list '9months
                   (N_ 9months)
                   (N_ "9 months")))
            (list->vector
             (list '12months
                   (N_ 12months)
                   (N_ "12 months")))
            (list->vector
             (list '18months
                   (N_ 18months)
                   (N_ "18 months")))
            (list->vector
             (list '24months
                   (N_ 24months)
                   (N_ "24 months")))
    )
)
    (define scale-num
        (list
        (cons '*  (vector gnc-numeric-mul (N_ "multiplied by ")))
        (cons '/  (vector gnc-numeric-div (N_ "divided by ")))
        ))

;; end of section 2 needed for gnctimeperiod-utilities

(define show-days? #t)

(define now (timespecCanonicalDayTime (cons (current-time) 0)))
(define today-tm (gnc:timepair->date now))

(define period_start (gnc:timepair->date now))
(define period_end (gnc:timepair->date now))

(define (gnc:date-lt? tm1 tm2)
    (if (not (= (tm:year tm1) (tm:year tm2)))
        (< (tm:year tm1) (tm:year tm2))
        ; years match
        (< (gnc:day-of-year tm1) (gnc:day-of-year tm2))
    ))

(define (getdates-average entrypicked exclude-last-period?)
(begin
(set! period_start (gnc:timepair->date now))
(set! period_end (gnc:timepair->date now))
(let ((day (gnc:day-of-week period_end))
      (fiscal-start (gnc:timepair->date (gnc:secs->timepair (gnc-accounting-period-fiscal-start))))
       ; (fiscal-month 0)
      (fiscal-day 1)
        )
    ;use period_end for weeks
   (set! fiscal-day (tm:mday fiscal-start))
   (set! period_end (gnc:decrement-date period_end (+ day 1) ))
   (if exclude-last-period?
     (set! period_end (gnc:decrement-date period_end 7 )))

    ;use period_start for months
   (set-tm:mday period_start fiscal-day)
   (if (gnc:date-lt? today-tm (gnc:decrement-date period_start 1 ))
       (begin
          (set-tm:mon period_start (- (tm:mon period_start) 1))
        ))
    (if exclude-last-period?
    (set! period_start (gnc:decrement-month period_start 1)))

   (case entrypicked
   ((4weeks)
        (set! period_start (gnc:decrement-date period_end (+ 6 (* 7 3)))))
   ((8weeks)
       (set! period_start (gnc:decrement-date period_end (+ 6 (* 7 7)))))
   ((12weeks)
       (set! period_start (gnc:decrement-date period_end (+ 6 (* 7 11)))))
   ((13weeks)
       (set! period_start (gnc:decrement-date period_end (+ 6 (* 7 12)))))
   ((26weeks)
       (set! period_start (gnc:decrement-date period_end (+ 6 (* 7 25)))))
   ((52weeks)
       (set! period_start (gnc:decrement-date period_end (+ 6 (* 7 51)))))
   ((3months)
        (set! period_start (gnc:decrement-month period_start 3))
        (set! period_end (gnc:increment-month-less-1-day period_start 3))
       )
   ((4months)
        (set! period_start (gnc:decrement-month period_start 4))
        (set! period_end (gnc:increment-month-less-1-day period_start 4))
       )
   ((6months)
        (set! period_start (gnc:decrement-month period_start 6))
        (set! period_end (gnc:increment-month-less-1-day period_start 6))
       )
   ((9months)
        (set! period_start (gnc:decrement-month period_start 9))
        (set! period_end (gnc:increment-month-less-1-day period_start 9))
       )
   ((12months)
        (set! period_start (gnc:decrement-month period_start 12))
        (set! period_end (gnc:increment-month-less-1-day period_start 12))
       )
    ((18months)
        (set! period_start (gnc:decrement-month period_start 18))
        (set! period_end (gnc:increment-month-less-1-day period_start 18))
       )
    ((24months)
        (set! period_start (gnc:decrement-month period_start 24))
        (set! period_end (gnc:increment-month-less-1-day period_start 24))
       )
   )

(list (gnc:timepair-start-day-time  (gnc:date->timepair period_start))
      (gnc:timepair-end-day-time  (gnc:date->timepair period_end)) )
)))

;for find

(define do-find? #f)
(define do-findamount? #f)
(define find-min? #f)
(define find-max? #f)
(define find-text? #f)
(define find1-field 'description )
(define find2-operand 'and)
(define find1-text  "text to find")
(define find2-field 'description )
(define find2-text "description to find")

(define find-min 100.00)
(define find-max 100.00)
(define findtitle "")


;;for running balance
(define amount-total-hash (make-hash-table))

;;for scaling
(define scale-op-val '*)
(define scale-num-val 1)
(define scaled? #f)
(define compare-scale-automatically? #f)
(define compare-scale-to-val 1)

;;for scaling comparison period
(define scale-op-val2 '*)
(define scale-num-val2 1)

(define description-titlecase? #t)
(define columns-headings 0)

;; for consolidate descriptions (create composite  - to combine multiple entries with same payee)
(define curr " ")
(define comm-curr? #f)
(define currency-type-num 1)
(define currency-type-str "1")

(define list_of_trans '())
(define sort-date-type 7)

(define currency-col-type 1)

(define primary-subtotal-collector-hash (make-hash-table))
(define secondary-subtotal-collector-hash (make-hash-table))
(define total-collector-hash (make-hash-table))

(define (sort-test x y var-p var-s comp-p1 comp-p2 comp-s1 comp-s2  )

    (define (test?  x y)
        (let ((primary-x  (var-p x))
            (primary-y  (var-p y))
            (secondary-x  (var-s x))
            (secondary-y  (var-s y)) )
            (if (not (comp-p1 primary-x primary-y ))
                    (comp-p2 primary-x primary-y)
                    (if (not (comp-s1 secondary-x secondary-y))
                        (comp-s2 secondary-x secondary-y )
                        (string-ci<=? (get-description x) (get-description y)))
                ))
    )
    (test? x y)
)



(define payee-hash (make-hash-table) )
(define payee-account-guid-hash (make-hash-table))
(define currency-type-hash (make-hash-table) )
(define currency-lookup-hash (make-hash-table) )

(define pointer-hash (make-hash-table))
(define amounts-array (make-array #f 2 3)) ; col 0 = currency type ; col 1 and greater - period
(define guid-array (make-array #f 2 3))
(define row-number 2); row 0 heading         row 1 number of days in the period
(define last-column 1)
(define period-number 0)



;; routine to sum up all descriptions with same payee and to store account guid and also non uppercase description
 (define (total-payee-hash-add! payee-hash payee amount payee-account-guid-hash guids+description )
    (begin
          (hash-set! payee-hash payee  (gnc-numeric-add amount  (hash-ref payee-hash payee (gnc-numeric-zero))  GNC-DENOM-AUTO GNC-RND-ROUND))
         (hash-set! payee-account-guid-hash payee guids+description )))

(define (get-primary-key transaction)
    (let* (
    ;;
            (thekey (car transaction))
            (endprimary (string-contains thekey "#Yw;"))
            (primary (if (< 0 endprimary)
                            (string-copy thekey 0 endprimary)
                    " ")) ;default
                    )
            primary
             )
    )

(define (get-secondary-key transaction)
    (let* (
            (thekey (car transaction))
            (startsecond (string-contains thekey "#Yw;"))
            (endsecond (string-contains thekey "#Yx;"))
            (secondary (if  (< 4 (- endsecond startsecond))
                        (string-copy thekey (+ 4 startsecond) endsecond)
                        " " ));default
                  )
            secondary
            )
    )
(define (get-date-key-tm the-key)
    (let* (
            (date (if  (< 7 (string-length the-key))
                    the-key
                    "20000114" ;default date
                  ))

            (year (string->number (string-copy date 0 4)))
            (month (string->number (string-copy date 4 6)))
            (day (string->number (string-copy date 6 8)))
        ;    (tm2 (strptime "%Y %m %d" (string-append (string-copy date 0 4)
        ;     " " (string-copy date 4 6) " " (string-copy date 6 8) )))
            (tm today-tm)
            )
            (set-tm:year tm (- year 1900))
            (set-tm:mon tm (- month 1))
            (set-tm:mday tm day)
             tm
             )
    )
(define (get-date-key-tp the-key)
    (gnc:date->timepair (get-date-key-tm the-key))
    )
(define (get-date-tm transaction)
    (let* (
            (thekey (car transaction))
            (startdate (string-contains thekey "#Yx;"))
            (enddate (string-contains thekey "#Yy;"))
            (date (if  (< 11 (- enddate startdate))
                    (string-copy thekey (+ 4 startdate) enddate)
                    "20000114" ;default date
                  ))

            (year (string->number (string-copy date 0 4)))
            (month (string->number (string-copy date 4 6)))
            (day (string->number (string-copy date 6 8)))
            (tm today-tm)
            )
            (set-tm:year tm (- year 1900))
            (set-tm:mon tm (- month 1))
            (set-tm:mday tm day)
             tm
             )
    )
(define (get-date-tp transaction)
    (gnc:date->timepair (get-date-tm transaction))
    )
(define (get-currency-type transaction)
    (let* (
            (thekey (car transaction))
            (startcurr (string-contains thekey "#Zu;"))
            (currency-type-str (if (< (+ startcurr 4) (string-length thekey))
                            (string-copy thekey (+ startcurr 4))
                            ;(string-take-right thekey (+ startcurr 4))
                            " ")))
            currency-type-str)
)
(define (get-memo transaction)
    (let* (
            (thekey (car transaction))
            (endmemo  (string-contains thekey "#Zv;"))
            (startmem (string-contains thekey "#Zw;"))
            (memo (if  (< 4 (- endmemo startmem))
                        (string-copy thekey  (+ startmem 4) endmemo)
                        " ")))
            memo)
)

(define (get-reverse-sign? transaction)
    (let* (
            (thekey (car transaction))
            (end  (string-contains thekey "#Zu;"))
            (start (string-contains thekey "#Zv;"))
            (rev-sign (if  (< 4 (- end start))
                        #t
                        #f)))
            rev-sign)
)

(define (get-description transaction)
    (let* (
            (thekey (car transaction))
            (startdescrip (string-contains thekey "#Yy;"))
            (enddescrip (string-contains thekey "#Yz;"))
            (description (if  (< 4 (- enddescrip startdescrip))
                        (string-copy thekey (+ 4 startdescrip) enddescrip)
                        " ")))
            description)
    )

(define (get-description-verbatim row)
;; the actual description entered by user - removes problems with upper and lower case
    (let* (
        (descript (caddr (array-ref guid-array row 0))))
        (if descript
        descript
        "")))
(define (get-namecode transaction)
    (let* (
            (thekey (car transaction))
            (startnamcode (string-contains thekey "#Yz;"))
            (endnamcode (string-contains thekey "#Zy;"))
            (namcode (if  (< 4 (- endnamcode startnamcode))
                        (string-copy thekey (+ 4 startnamcode) endnamcode)
                        " ")))
            namcode)
    )

(define (get-account-code transaction)
    (let* (
            (thekey (car transaction))
            (startcod  (string-contains thekey "#Zy;"))
            (endothercod (string-contains thekey "#Zx;"))
            (acctcod (if  (< 4 (- endothercod startcod))
                        (string-copy thekey  (+ startcod 4) endothercod)
                        " ")))
            acctcod)
    )


(define (get-other-name transaction)
    (let* (
            (thekey (car transaction))
            (endacctname  (string-contains thekey "#Zx;"))
            (endothernam (string-contains thekey "#Zw;"))
            (othernam (if  (< 4 (- endothernam endacctname))
                        (string-copy thekey  (+ endacctname 4) endothernam)
                        " ")))
            othernam)
    )

(define (get-accountname-from-sort thekey transaction)
    (let ((start-account (string-contains thekey "#Yv;")))
        (if start-account
            (if (< (+ 4 start-account) (string-length thekey) )
                (string-append (get-account-code transaction)  (substring thekey (+ 4 (string-contains thekey "#Yv;"))))
                " ")
        thekey)
        ))

(define (get-accountguid transaction)
;; we stored (account-guid (gncAccountGetGUID account))
    (let* ( (row (get-row-in-array transaction))
        (accountguid (cadr (array-ref guid-array row 0))))
        (if accountguid
        accountguid
        "")))

(define (get-transguid row column)
;; we stored (account-guid (gncAccountGetGUID account))
    (let* (
        (transguid (if (array-ref guid-array row column)
            (car (array-ref guid-array row column))
            "")))
        transguid
        ))

(define (get-split-value-numer transaction)
    (let (
            (split-value-comp (cdr transaction))
            ;  (split-value-comp (gnc:make-gnc-numeric 12 1))
            )
            split-value-comp)
)


(define (get-row-in-array transaction)
    (cdr transaction)
)
(define (get-array-value-num-base transaction) ;note values are scaled when stored in array
    (let* ( (row (get-row-in-array transaction))
            (split-value-ar
                    (array-ref amounts-array row 1)) ;column is 1 since for base period
            (value (if (gnc:gnc-monetary? split-value-ar)
                    (gnc:gnc-numeric-num (gnc:gnc-monetary-amount split-value-ar))
                        0.0)))
            value
            )
)

(define (get-monetary key column) ;note values are scaled when stored in array
    (let* ( (row (get-row-in-array key))
            (split-value-ar
                    (array-ref amounts-array row column))
            (value (if (gnc:gnc-monetary? split-value-ar)
                        split-value-ar
                    ;(gnc:make-gnc-monetary report-currency (gnc:make-gnc-numeric 2 1))))
                    (gnc:make-gnc-monetary
                       (hash-ref currency-lookup-hash (get-currency-type key))
                        split-value-ar)))
            )
            value
))





(define (gnc:comp-register-guid type guid)
  (gnc-build-url URL-TYPE-REGISTER (string-append type guid) ""))

(define (gnc-comp:transaction-anchor-text trans)
  (gnc:comp-register-guid "trans-guid=" (gncTransGetGUID trans)))

 (define (get-gnc:comp-transaction-anchor-text row column)
  (gnc:comp-register-guid "trans-guid=" (get-transguid row column)))

(define (gnc:comp-html-transaction-anchor row column text)
  (gnc:make-html-text (gnc:html-markup-anchor
                       (get-gnc:comp-transaction-anchor-text row column)
                       text)))

(define (get-gnc:account-anchor-text split-trans)
    ;(gnc:register-guid "acct-guid=" (gncAccountGetGUID acct)))
    (let* ( (acctguid (get-accountguid split-trans)))
        (if acctguid
            (gnc:comp-register-guid "acct-guid=" acctguid)
            "")))


;; for imbalance and orphan accounts
(define (gnc:accounts-imbalance-or-orphan start-date-tp end-date-tp)
;; returns list of accounts starting with the letters "imbalanc"  which do not have a zero (0)
;; change in the balance between the start date and the end date
    (let* (
        (all-accounts (gnc-account-get-descendants-sorted
                            (gnc-get-current-root-account)))
        )
        (filter (lambda (acct)
                (if  (or (string-prefix-ci? "imbalance" (gnc-account-get-full-name acct))
                    (string-prefix-ci? "orphan" (gnc-account-get-full-name acct)))
                ;; check if the change in balance from the 'from' date to the 'to' date.
                ;; is 0
                (if (equal? (gnc-numeric-zero) (gnc:account-get-balance-interval acct start-date-tp end-date-tp #f))
                    #f
                    #t)
                #f))
          all-accounts)
))
;; end for imbalance


;; for consolidating
(define (sortkeys list-thekeys var-p var-s comp-p1 comp-p2 comp-s1 comp-s2)(sort list-thekeys
            ;1 sort by primary key and secondary key
            ;2 sort by primary key and amount
            ;3 sort by amount and secondary key
            ;4 sort by amount and amount
        ; will do 3rd sort on description


     (lambda (x y)
            (let (  (primary-x  (var-p x))
                (primary-y  (var-p y))
                (secondary-x  (var-s x))
                (secondary-y  (var-s y)) )
                (if (not (comp-p1 primary-x primary-y ))
                    (comp-p2 primary-x primary-y)
                    (if (not (comp-s1 secondary-x secondary-y))
                        (comp-s2 secondary-x secondary-y )
                        (string-ci<=? (get-description x) (get-description y)))
                ))
        )

    ))

;; The option-values of the sorting key multichoice option, for
;; which a subtotal should be enabled.
(define comp-subtotal-enabled '(account-name
                           account-code
                           corresponding-acc-name
                           corresponding-acc-code))

(define (comp-split-account-full-name-same-p a b)
  (equal? a  b))

(define (comp-split-account-code-same-p a b)
  (equal? a b))

(define (comp-split-same-corr-account-full-name-p a b)
  (equal? a b))

(define (comp-split-same-corr-account-code-p a b)
  (equal? a b))

(define (comp-timepair-same-year tp-a tp-b)
  (= (gnc:timepair-get-year tp-a)
     (gnc:timepair-get-year tp-b)))

(define (comp-timepair-same-quarter tp-a tp-b)
  (and (comp-timepair-same-year tp-a tp-b)
       (= (gnc:timepair-get-quarter tp-a)
          (gnc:timepair-get-quarter tp-b))))

(define (comp-timepair-same-month tp-a tp-b)
  (and (comp-timepair-same-year tp-a tp-b)
       (= (gnc:timepair-get-month tp-a)
          (gnc:timepair-get-month tp-b))))

(define (comp-timepair-same-week tp-a tp-b)
  (and (comp-timepair-same-year tp-a tp-b)
       (= (gnc:timepair-get-week tp-a)
      (gnc:timepair-get-week tp-b))))

(define (comp-split-same-week-p a b)
  (let ((tp-a (get-date-key-tp a))
        (tp-b (get-date-key-tp b)))
    (comp-timepair-same-week tp-a tp-b)))

(define (comp-split-same-month-p a b)
  (let ((tp-a (get-date-key-tp a))
        (tp-b (get-date-key-tp b)))
    (comp-timepair-same-month tp-a tp-b)))

(define (comp-split-same-quarter-p a b)
  (let ((tp-a (get-date-key-tp a))
        (tp-b (get-date-key-tp b)))
    (comp-timepair-same-quarter tp-a tp-b)))

(define (comp-split-same-year-p a b)
  (let ((tp-a (get-date-key-tp a))
        (tp-b (get-date-key-tp b)))
    (comp-timepair-same-year tp-a tp-b)))
;;

(define (comp-set-last-row-style! table tag . rest)
  (let ((arg-list
         (cons table
               (cons (- (gnc:html-table-num-rows table) 1)
                     (cons tag rest)))))
    (apply gnc:html-table-set-row-style! arg-list)))

(define (comp-add-subheading-row data table width subheading-style)
  (let ((heading-cell (gnc:make-html-table-cell data)))
    (gnc:html-table-cell-set-colspan! heading-cell width)
    (gnc:html-table-append-row/markup!
     table
     subheading-style
     (list heading-cell))))

;; display an account name depending on the options the user has set
(define (comp-account-namestring account show-account-code show-account-name show-account-full-name)
  ;;# on multi-line splits we can get an empty ('()) account
  (if (null? account)
        (_ "Split Transaction")
        (string-append
           ;; display account code?
           (if show-account-code
                 (string-append (xaccAccountGetCode account) " ")
                 "")
           ;; display account name?
           (if show-account-name
                 ;; display full account name?
                 (if show-account-full-name
                      (gnc-account-get-full-name account)
                      (xaccAccountGetName account))
                 ""))))

;; render an account subheading - column-vector determines what is displayed
(define (comp-render-account-subheading
         split-trans the-key table width subheading-style column-vector)
  (let ((accountname  (get-accountname-from-sort the-key split-trans)))
    (comp-add-subheading-row (gnc:make-html-text
                         (gnc:html-markup-anchor
                           (get-gnc:account-anchor-text split-trans)
                           accountname) )
                        table width subheading-style)))

(define (comp-render-corresponding-account-subheading
         split-trans the-key table width subheading-style column-vector)
  (let ((accountname the-key))
    (comp-add-subheading-row (gnc:make-html-text
                         (gnc:html-markup-anchor
                          (if (not (null? split-trans))
                           (get-gnc:account-anchor-text split-trans)
                           "")
                           accountname) )
                        table width subheading-style)))

(define (comp-render-week-subheading split-trans the-key table width subheading-style column-vector)
  (comp-add-subheading-row (gnc:date-get-week-year-string
               (get-date-tm split-trans))
              table width subheading-style))

(define (comp-render-month-subheading split-trans the-key table width subheading-style column-vector)
  (comp-add-subheading-row (gnc:date-get-month-year-string
                      (get-date-tm split-trans))
                     table width subheading-style))

(define (comp-render-quarter-subheading split-trans the-key table width subheading-style column-vector)
  (comp-add-subheading-row (gnc:date-get-quarter-year-string
                      (get-date-tm split-trans))
                     table width subheading-style))

(define (comp-render-year-subheading split-trans the-key table width subheading-style column-vector)
  (comp-add-subheading-row (gnc:date-get-year-string
                      (get-date-tm split-trans))
                      table width subheading-style))


(define (comp-add-subtotal-row table width subtotal-string subtotal-collector subtotal-collector-hash
                          subtotal-style export?)
  (let ((currency-totals (subtotal-collector
                          'format gnc:make-gnc-monetary #f))
        (blanks (gnc:make-html-table-cell/size 1 (- width 1) #f))
        (row-contents '())
        (the-currency 1))

    (while (< the-currency currency-type-num)
        (let ((currency (hash-ref currency-lookup-hash (number->string the-currency)))
              (col 1)
              (count-spaces 1))
        (if (= the-currency 1)
         (addto! row-contents
                    (gnc:make-html-table-cell/markup "total-label-cell" subtotal-string))
         (addto! row-contents
                    (gnc:make-html-table-cell/markup "total-label-cell" " " )))
        (set! count-spaces (+ count-spaces 1))
        ; I can't figure out how to get blanks so brute force
            (while (< count-spaces columns-headings )
                (addto! row-contents
                    (gnc:make-html-table-cell/markup
                        "total-number-cell"
                " " ))
            (set! count-spaces (+ 1 count-spaces))
            )
          (while (<= col last-column)
           (addto! row-contents
                (gnc:make-html-table-cell/markup
                                "total-number-cell" (hash-ref subtotal-collector-hash
                                (string-append (number->string col) "#Vv;" (number->string the-currency))
                                (gnc:make-gnc-monetary currency (gnc-numeric-zero)))))
        (set! col (+ col 1))
        )
        (set! the-currency (+ the-currency 1))
    )
    (gnc:html-table-append-row/markup! table subtotal-style
            (reverse row-contents))
    (set! row-contents '()))
    ))


(define (comp-total-string str) (string-append (_ "Total For ") str))

(define (comp-render-account-subtotal
          table width split the-key  total-collector total-collector-hash subtotal-style column-vector export?)
    (comp-add-subtotal-row table width
                      (total-string (get-accountname-from-sort the-key split))
                      total-collector total-collector-hash subtotal-style export?))

(define (comp-render-corresponding-account-subtotal
         table width split the-key  total-collector total-collector-hash subtotal-style column-vector export?)
    (comp-add-subtotal-row table width
                      (total-string the-key)
                    total-collector total-collector-hash subtotal-style export?))

(define (comp-render-week-subtotal
     table width split the-key total-collector total-collector-hash subtotal-style column-vector export?)
  (let ((tm (get-date-tm split)))
    (comp-add-subtotal-row table width
              (total-string (gnc:date-get-week-year-string tm))
              total-collector total-collector-hash subtotal-style export?)))

(define (comp-render-month-subtotal
         table width split the-key total-collector total-collector-hash subtotal-style column-vector export?)
  (let ((tm (get-date-tm split)))
    (comp-add-subtotal-row table width
                      (total-string (gnc:date-get-month-year-string tm))
                      total-collector total-collector-hash subtotal-style export?)))


(define (comp-render-quarter-subtotal
         table width split the-key total-collector total-collector-hash subtotal-style column-vector export?)
  (let ((tm (get-date-tm split)))
    (comp-add-subtotal-row table width
                      (total-string (gnc:date-get-quarter-year-string tm))
                     total-collector total-collector-hash subtotal-style export?)))

(define (comp-render-year-subtotal
         table width split the-key total-collector total-collector-hash subtotal-style column-vector export?)
  (let ((tm (get-date-tm split)))
    (comp-add-subtotal-row table width
                      (total-string (strftime "%Y" tm))
                      total-collector total-collector-hash subtotal-style export?)))


(define (comp-render-grand-total
         table width total-collector total-collector-hash export?)
  (comp-add-subtotal-row table width
                    (_ "Grand Total")
                    total-collector total-collector-hash def:grand-total-style export?))

;; end section for consolidating


;;following part of original transaction.scm
;; The option-values of the sorting key multichoice option, for
;; which a subtotal should be enabled.
(define subtotal-enabled '(account-name
                           account-code
                           corresponding-acc-name
                           corresponding-acc-code))

(define (split-account-full-name-same-p a b)
  (= (xaccSplitCompareAccountFullNames a b) 0))

(define (split-account-code-same-p a b)
  (= (xaccSplitCompareAccountCodes a b) 0))

(define (split-same-corr-account-full-name-p a b)
  (= (xaccSplitCompareOtherAccountFullNames a b) 0))

(define (split-same-corr-account-code-p a b)
  (= (xaccSplitCompareOtherAccountCodes a b) 0))

(define (timepair-same-year tp-a tp-b)
  (= (gnc:timepair-get-year tp-a)
     (gnc:timepair-get-year tp-b)))

(define (timepair-same-quarter tp-a tp-b)
  (and (timepair-same-year tp-a tp-b)
       (= (gnc:timepair-get-quarter tp-a)
          (gnc:timepair-get-quarter tp-b))))

(define (timepair-same-month tp-a tp-b)
  (and (timepair-same-year tp-a tp-b)
       (= (gnc:timepair-get-month tp-a)
          (gnc:timepair-get-month tp-b))))

(define (timepair-same-week tp-a tp-b)
  (and (timepair-same-year tp-a tp-b)
       (= (gnc:timepair-get-week tp-a)
      (gnc:timepair-get-week tp-b))))

(define (split-same-week-p a b)
  (let ((tp-a (gnc-transaction-get-date-posted (xaccSplitGetParent a)))
    (tp-b (gnc-transaction-get-date-posted (xaccSplitGetParent b))))
    (timepair-same-week tp-a tp-b)))

(define (split-same-month-p a b)
  (let ((tp-a (gnc-transaction-get-date-posted (xaccSplitGetParent a)))
        (tp-b (gnc-transaction-get-date-posted (xaccSplitGetParent b))))
    (timepair-same-month tp-a tp-b)))

(define (split-same-quarter-p a b)
  (let ((tp-a (gnc-transaction-get-date-posted (xaccSplitGetParent a)))
        (tp-b (gnc-transaction-get-date-posted (xaccSplitGetParent b))))
    (timepair-same-quarter tp-a tp-b)))

(define (split-same-year-p a b)
  (let ((tp-a (gnc-transaction-get-date-posted (xaccSplitGetParent a)))
        (tp-b (gnc-transaction-get-date-posted (xaccSplitGetParent b))))
    (timepair-same-year tp-a tp-b)))

(define (set-last-row-style! table tag . rest)
  (let ((arg-list
         (cons table
               (cons (- (gnc:html-table-num-rows table) 1)
                     (cons tag rest)))))
    (apply gnc:html-table-set-row-style! arg-list)))


;; display an account name depending on the options the user has set
(define (account-namestring account show-account-code show-account-name show-account-full-name)
  ;;# on multi-line splits we can get an empty ('()) account
  (if (null? account)
        (_ "Split Transaction")
        (string-append
           ;; display account code?
           (if show-account-code
                 (string-append (xaccAccountGetCode account) " ")
                 "")
           ;; display account name?
           (if show-account-name
                 ;; display full account name?
                 (if show-account-full-name
                      (gnc-account-get-full-name account)
                      (xaccAccountGetName account))
                 ""))))


(define (total-string str) (string-append (_ "Total For ") str))


(define account-types-to-reverse-assoc-list
  (list (cons 'none '())
        (cons 'income-expense
              (list ACCT-TYPE-INCOME ACCT-TYPE-EXPENSE))
        (cons 'credit-accounts
              (list ACCT-TYPE-LIABILITY ACCT-TYPE-PAYABLE ACCT-TYPE-EQUITY
                    ACCT-TYPE-CREDIT ACCT-TYPE-INCOME))))

(define (get-account-types-to-reverse options)
    (cdr (assq (gnc:option-value
                (gnc:lookup-option options
                                   pagename-display
                                   (N_ "Sign Reverses")))
               account-types-to-reverse-assoc-list)))

(define (used-date columns-used)
  (vector-ref columns-used 0))
(define (used-reconciled-date columns-used)
  (vector-ref columns-used 1))
(define (used-num columns-used)
  (vector-ref columns-used 2))
(define (used-description columns-used)
  (vector-ref columns-used 3))
(define (used-account-name columns-used)
  (vector-ref columns-used 4))
(define (used-other-account-name columns-used)
  (vector-ref columns-used 5))
(define (used-shares columns-used)
  (vector-ref columns-used 6))
(define (used-price columns-used)
  (vector-ref columns-used 7))
(define (used-amount-single columns-used)
  (vector-ref columns-used 8))
(define (used-amount-double-positive columns-used)
  (vector-ref columns-used 9))
(define (used-amount-double-negative columns-used)
  (vector-ref columns-used 10))
(define (used-running-balance columns-used)
  (vector-ref columns-used 11))
(define (used-account-full-name columns-used)
  (vector-ref columns-used 12))
(define (used-memo columns-used)
  (vector-ref columns-used 13))
(define (used-account-code columns-used)
  (vector-ref columns-used 14))
(define (used-other-account-code columns-used)
  (vector-ref columns-used 15))
(define (used-other-account-full-name columns-used)
  (vector-ref columns-used 16))
(define (used-sort-account-code columns-used)
  (vector-ref columns-used 17))
(define (used-sort-account-full-name columns-used)
  (vector-ref columns-used 18))
(define (used-notes columns-used)
  (vector-ref columns-used 19))

(define columns-used-size 20)

(define (num-columns-required columns-used)  ; this routine is called but results don't seem to be used
  (do ((i 0 (+ i 1))
       (col-req 0 col-req))
      ((>= i columns-used-size) col-req)
    ; If column toggle is true, increase column count. But attention:
    ; some toggles only change the meaning of another toggle. Don't count these modifier toggles
    (if (and (not (= i 12)) ; Skip Account Full Name toggle - modifies Account Name column
             (not (= i 16)) ; Skip Other Account Full Name toggle - modifies Other Account Name column
             (not (= i 17)) ; Skip Sort Account Code - modifies Account Name subheading
             (not (= i 18)) ; Skip Sort Account Full Name - modifies Account Name subheading
             (not (= i 19)) ; Skip Note toggle - modifies Memo column
             (vector-ref columns-used i))
      (set! col-req (+ col-req 1)))
    ; Account Code and Account Name share one column so if both were ticked the
    ; the check above would have set up one column too much. The check below
    ; will compensate these again.
    (if (or (and (= i 14) (vector-ref columns-used 14) (vector-ref columns-used 4)) ; Account Code and Name
            (and (= i 15) (vector-ref columns-used 15) (vector-ref columns-used 5))) ; Other Account Code and Name
       (set! col-req (- col-req 1)))
      ))

(define (build-column-used options)
  (define (opt-val section name)
    (gnc:option-value
     (gnc:lookup-option options section name)))
  (let ((column-list (make-vector columns-used-size #f)))
    (if (opt-val pagename-display (N_ "Description"))
        (vector-set! column-list 3 #t))
    (if (opt-val pagename-display (N_ "Account Name"))
        (vector-set! column-list 4 #t))
    (if (opt-val pagename-display (N_ "Other Account Name"))
        (vector-set! column-list 5 #t))
 ;   (if (opt-val pagename-display (N_ "Shares"))
 ;       (vector-set! column-list 6 #t))
;    (if (opt-val pagename-display (N_ "Price"))
;        (vector-set! column-list 7 #t))
    (vector-set! column-list 8 #t) ; set as always single
   ; (if (opt-val pagename-display (N_ "Running Balance"))
   ;     (vector-set! column-list 11 #t))
    (if (opt-val pagename-display  (N_ "Use Full Account Name"))
        (vector-set! column-list 12 #t))
    (if (opt-val pagename-display (N_ "Memo"))
        (vector-set! column-list 13 #t))
    (if (opt-val pagename-display (N_ "Account Code"))
        (vector-set! column-list 14 #t))
    (if (opt-val pagename-display (N_ "Other Account Code"))
        (vector-set! column-list 15 #t))
    (if (opt-val pagename-display (N_ "Use Full Other Account Name"))
        (vector-set! column-list 16 #t))
    (if (opt-val pagename-sorting (N_ "Show Account Code"))
        (vector-set! column-list 17 #t))
    (if (opt-val pagename-sorting (N_ "Show Full Account Name"))
        (vector-set! column-list 18 #t))
    (if (opt-val pagename-display (N_ "Notes"))
        (vector-set! column-list 19 #t))
    column-list))

(define (make-heading-list column-vector options)
  (let ((heading-list '()))
    (if (used-description column-vector)
        (addto! heading-list (_ "Description")))
    (if (used-memo column-vector)
        (if (used-notes column-vector)
            (addto! heading-list (string-append (_ "Memo") "/" (_ "Notes")))
            (addto! heading-list (_ "Memo"))))
    (if (or (used-account-name column-vector) (used-account-code column-vector))
        (addto! heading-list (_ "Account")))
    (if (or (used-other-account-name column-vector) (used-other-account-code column-vector))
        (addto! heading-list (_ "Transfer from/to")))
    (if (used-shares column-vector)
        (addto! heading-list (_ "Shares")))
    (if (used-price column-vector)
        (addto! heading-list (_ "Price")))
    (if (used-amount-single column-vector)
       ; (addto! heading-list (_ "Amount")))
        (addto!  heading-list
        (gnc:make-html-table-cell/markup
                       "column-heading-center"
                  (array-ref amounts-array
                            0 1
                             ))))
    ;; FIXME: Proper labels: what?
    (if (used-amount-double-positive column-vector)
        (addto! heading-list (_ "Debit")))
    (if (used-amount-double-negative column-vector)
        (addto! heading-list (_ "Credit")))
    (if (used-running-balance column-vector)
        (addto! heading-list (_ "Balance")))
    (set! columns-headings (length heading-list))
    ;(if compare?
    (let* ( (col 2))
            (while (<= col last-column)
        (addto!  heading-list
        (gnc:make-html-table-cell/markup
                       "column-heading-center"
                (array-ref amounts-array
                            0 col
                             )))
        (set! col (+ col 1))))
;    )
    (reverse heading-list)))
;;

;;
(define (make-heading-days table row-style)
  (let ((heading-list '())
        (col 2))
        (addto!  heading-list
            (gnc:make-html-text (gnc:html-markup-b
                (_ text-number-days))))
        (while (< col columns-headings)
            (addto!  heading-list
                (_ " "))
            (set! col (+ col 1)))

    (let* ( (col 1))
        (while (<= col last-column)
            (addto!  heading-list
                (gnc:make-html-table-cell/markup
                  "column-heading-right"
                 (if (and show-average? (= col 3))
                    ""
                   (display-num-days
                   (array-ref amounts-array
                            1 col
                             )))))
            (set! col (+ col 1))))
    (gnc:html-table-append-row! table
    (reverse heading-list)))
)

(define (make-heading-scale table row-style)
  (let ((heading-list '())
        (col 2))
        (addto!  heading-list
            (gnc:make-html-text (gnc:html-markup-b
                (if compare-scale-automatically?

                    (_ "  Scaled to:")
                    (_ "  Scaled by:")))))
        (while (< col columns-headings)
            (addto!  heading-list
                (_ " "))
            (set! col (+ col 1)))
        (addto!  heading-list
            ;(gnc:make-html-text (gnc:html-markup-b
            (gnc:make-html-table-cell/markup
                       "column-heading-right"
                (if compare-scale-automatically?
                    (_ (number->string compare-scale-to-val))
                    (_ (string-append (vector-ref (cdr (assq scale-op-val  scale-num)) 1) (number->string scale-num-val))))))

    (let* ( (col 2))
        (while (<= col last-column)
            (addto!  heading-list
            (gnc:make-html-table-cell/markup
                  "column-heading-right"
                (if (and show-average? (or (= col 3) (= col 4)))
                    ""
                (if compare-scale-automatically?
                    (_ (number->string compare-scale-to-val))
                    (_ (string-append (vector-ref (cdr (assq scale-op-val2  scale-num)) 1) (number->string scale-num-val2)))))))
                ;    (_ (number->string scale-num-val2)))))
            (set! col (+ col 1))))
    (gnc:html-table-append-row! table
    (reverse heading-list)))
)

;; following section for composite/consolidate transactions
(define (add-split-row-comp table split-trans column-vector options
                       row-style account-types-to-reverse transaction-row?)

  (define (opt-val section name)
    (gnc:option-value
     (gnc:lookup-option options section name)))

  (let* ((row-contents '())
     (dummy  (gnc:debug "split-trans is originally" split-trans))
        (report-currency (hash-ref currency-lookup-hash (get-currency-type split-trans)))
        (currency-frac (gnc-commodity-get-fraction report-currency))
        (row-in-array (get-row-in-array split-trans))
        (split-value-ar (get-monetary split-trans 1))
        (split-value-ar-coll (if (get-reverse-sign? split-trans)
                (gnc:make-gnc-monetary report-currency (gnc-numeric-neg (gnc:gnc-monetary-amount split-value-ar)))
                split-value-ar))
        (found? #t)
        (col 1))

        (if do-findamount?
            (begin
                (set! found? #f)
                (while (<= col last-column)
                (if (find-monetary? (get-monetary split-trans col))
                ;(if (>= (gnc:gnc-numeric-num (gnc:gnc-monetary-amount (get-monetary split-trans col))) find-min )
                    (set! found? #t))
        (set! col (+ col 1)))
        ))

    (if (used-description column-vector)
        (addto! row-contents
                (if transaction-row?
                    (gnc:make-html-table-cell/markup "text-cell"
                       (if description-titlecase?
                        (string-titlecase (get-description-verbatim row-in-array))
                        (get-description-verbatim row-in-array)))
                     " ")))

    (if (used-memo column-vector)
        (addto! row-contents
            (get-memo split-trans)
            ))

    (if (or (used-account-name column-vector) (used-account-code column-vector))
       (addto! row-contents (get-namecode split-trans)))

    (if (or (used-other-account-name column-vector) (used-other-account-code column-vector))
       (addto! row-contents (get-other-name split-trans)))

    (if (used-shares column-vector)
        (addto! row-contents " "))

    (if (used-price column-vector)
        (addto!
         row-contents
         " "))

    (if (used-amount-single column-vector);; always true

            (let* ( (colmn 1))
            (while (<= colmn last-column)
                (addto! row-contents
                ; the amount is printed here
                (gnc:make-html-table-cell/markup "number-cell"
                (if (and show-average? (= colmn 4))
                    ""
                    (gnc:comp-html-transaction-anchor
                        row-in-array colmn
                        (get-monetary split-trans colmn)))))
                (set! colmn (+ colmn 1))))
        )
    (if found?
    (gnc:html-table-append-row/markup! table row-style
                                       (reverse row-contents)))
    split-value-ar-coll))

;end section -consolite

(define date-sorting-types (list 'date 'exact-time 'register-order))

(define (trep-options-generator)
  (define gnc:*transaction-report-options* (gnc:new-options))
  (define (gnc:register-trep-option new-option)
    (gnc:register-option gnc:*transaction-report-options* new-option))







 ;; General options

;; To add gnctimeperiod-utilities comment out  old  period over which to report income
;; and add section 3
;;

;;  (gnc:options-add-date-interval!
 ;;  gnc:*transaction-report-options*
 ;;  pagename-general (N_ "Start Date") (N_ "End Date") "a")
;;

;;
 ;; step 3 of 4 to add gnctimeperiod-utilities
     ;add  select custom date or a specific period
     ; changed add-option to gnc:register-trep-option
(let ((periodoptions gnc:*transaction-report-options*))
    (gnc:register-trep-option
        (gnc:make-multichoice-callback-option
    ;    (gnc:make-multichoice-option
        the_tab (N_ text-whichperiod)
        "ca" (N_ "Select which time period to use")
        'last
;;        gnc:list-datechoices
;;        ))
        gnc:list-datechoices #f
        (lambda (x)
        (gnc-option-db-set-option-selectable-by-name
         periodoptions the_tab (N_ text-pick-year)
         (if (equal? x 'customdates) #f #t))
        (gnc-option-db-set-option-selectable-by-name
         periodoptions the_tab (N_ text-period)
         (if (equal? x 'period) #t #f))
        (gnc-option-db-set-option-selectable-by-name
         periodoptions the_tab (N_ text-last)
         (if (equal? x 'last) #t #f))
        (gnc-option-db-set-option-selectable-by-name
         periodoptions the_tab (N_ text-month)
         (if (equal? x 'month) #t #f))
        ))
    ))
     ; add  custom date
    (gnc:options-add-date-interval!
     gnc:*transaction-report-options* the_tab
        custom-from-date custom-to-date "cb")

     ;  add pick year for specific period
    (gnc:register-trep-option
        (gnc:make-multichoice-option the_tab (N_ text-pick-year)
        "ce" (N_ "Pick the year for report") 'this-yr
        gnc:list-years
        ))
     ;  add pick specific period
    (gnc:register-trep-option
        (gnc:make-multichoice-option the_tab (N_ text-period)
        "cf" (N_ "Pick portion of the year for report") 'fullyear
        gnc:list-periods
        ))
    ; add pick specific last XX
    (gnc:register-trep-option
        (gnc:make-multichoice-option the_tab (N_ text-last)
        "cg" (N_ "Pick portion of the year for report") 'lastmonth
        gnc:list-lasts
        ))
      ; add pick specific month
    (gnc:register-trep-option
        (gnc:make-multichoice-option the_tab (N_ text-month)
        "ch" (N_ "Pick which month for report") '4
        gnc:list-months
        ))
      ; add pick for multiply or divide
    (gnc:register-trep-option
        (gnc:make-multichoice-option the_tab (N_ "Scale Results")
        "ci" (N_ "Scale the results - multiply or divide by scale factor") '*
        gnc:list-operands
        ))
    ; add where number for multiply or divide can be changed
    (gnc:register-trep-option
        (gnc:make-number-range-option the_tab (N_ "Scale Number Option")
        "cj" (N_ "Number to multiply or divide by")
            1.0     ;; default
            1       ;; lower bound
          366.0     ;; upper bound
            2.0     ;; number of decimals
            1.0    ;; step size
        ))
;;end of section 3 for gnctimeperiod-utilities
;;
     ;add  select custom date or a specific period
     ; changed add-option to gnc:register-trep-option
(let ((periodoptions gnc:*transaction-report-options*))


    (gnc:register-trep-option
      (gnc:make-complex-boolean-option
        pagename-compare optname-compare?
        "a1" (N_ "Compare multiple periods") #t
        #f
            (lambda (x)
        (gnc-option-db-set-option-selectable-by-name
         periodoptions pagename-compare optname-no-base?
         x))
         ))

    (gnc:register-trep-option
    (gnc:make-simple-boolean-option
        pagename-compare optname-no-base?
        "a2" (N_ "If compare periods is unchecked and this box checked only comparison period will be displayed") #f))


    (gnc:register-trep-option
    (gnc:make-simple-boolean-option
        pagename-compare optname-show-average?
        "a3" (N_ "Show average for comparison period along with delta from average period") #t))

    (gnc:register-trep-option
        (gnc:make-multichoice-option pagename-compare (N_ text-compare-divide)
        "b" (N_ "Divide period into smaller periods") 'months
        gnc:list-comparechoices
        ))

    (gnc:register-trep-option
        (gnc:make-multichoice-callback-option
    ;    (gnc:make-multichoice-option
        pagename-compare (N_ text-whichcompareperiod)
        "ca" (N_ "Select which time period to use")
        'average
;;        gnc:list-datechoices-avg
;;        ))
        gnc:list-datechoices-avg #f
        (lambda (x)
        (gnc-option-db-set-option-selectable-by-name
         periodoptions pagename-compare (N_ text-pick-year)
         (if (equal? x 'customdates) #f #t))
        (gnc-option-db-set-option-selectable-by-name
         periodoptions pagename-compare (N_ text-period)
         (if (equal? x 'period) #t #f))
        (gnc-option-db-set-option-selectable-by-name
         periodoptions pagename-compare (N_ text-last)
         (if (equal? x 'last) #t #f))
        (gnc-option-db-set-option-selectable-by-name
         periodoptions pagename-compare (N_ text-month)
         (if (equal? x 'month) #t #f))
         (gnc-option-db-set-option-selectable-by-name
         periodoptions pagename-compare (N_ text-average)
         (if (equal? x 'average) #t #f))
         (gnc-option-db-set-option-selectable-by-name
         periodoptions pagename-compare (N_ text-exclude-average)
         (if (equal? x 'average) #t #f))
        ))
    ))
     ; add  custom date
    (gnc:options-add-date-interval!
     gnc:*transaction-report-options* pagename-compare
        custom-from-date custom-to-date "cb")

     ;  add pick year for specific period
    (gnc:register-trep-option
        (gnc:make-multichoice-option pagename-compare (N_ text-pick-year)
        "cc" (N_ "Pick the year for report") 'last-yr
        gnc:list-years
        ))

    ;  add pick specific period
    (gnc:register-trep-option
        (gnc:make-multichoice-option pagename-compare (N_ text-period)
        "cf" (N_ "Pick portion of the year for report") 'fullyear
        gnc:list-periods
        ))
    ; add pick specific last XX
    (gnc:register-trep-option
        (gnc:make-multichoice-option pagename-compare (N_ text-last)
        "cg" (N_ "Pick portion of the year for report") 'last_qtr
        gnc:list-lasts
        ))
      ; add pick specific month
    (gnc:register-trep-option
        (gnc:make-multichoice-option pagename-compare (N_ text-month)
        "ch" (N_ "Pick which month for report") '4
        gnc:list-months
        ))
     ;  add exclude last week or month from average
      (gnc:register-trep-option
    (gnc:make-simple-boolean-option
        pagename-compare (N_ text-exclude-average)
        "ci" (N_ "Do not include the last week in week averages, last month in month averages") #t
        ))
     ;  add pick average period
    (gnc:register-trep-option
        (gnc:make-multichoice-option pagename-compare (N_ text-average)
        "cj" (N_ "Pick portion of the year for report") '3months
        gnc:list-average
        ))
      ; add pick for multiply or divide
    (gnc:register-trep-option
        (gnc:make-multichoice-option pagename-compare (N_ "Scale Results")
        "d1" (N_ "Scale the results - multiply or divide by scale factor") '*
        gnc:list-operands
        ))
    ; add where number for multiply or divide can be changed
    (gnc:register-trep-option
        (gnc:make-number-range-option pagename-compare (N_ "Scale Number Option")
        "d2" (N_ "Number to multiply or divide by")
            1.0     ;; default
            1       ;; lower bound
          366.0     ;; upper bound
            2.0     ;; number of decimals
            1.0    ;; step size
        ))
;;end of section 3 for gnctimeperiod-utilities


    (gnc:register-trep-option
        (gnc:make-simple-boolean-option
            pagename-compare optname-scale-automatically?
            "e" (N_ "Scale all periods to number of days given below") #f))

    (gnc:register-trep-option
        (gnc:make-number-range-option pagename-compare optname-scale-to
        "f" (N_ "Scale all periods including the base to this number of days")
          365.0     ;; default
            1       ;; lower bound
          366.0     ;; upper bound
            0       ;; number of decimals
            1.0     ;; step size
        ))

 ; (gnc:register-trep-option
 ;  (gnc:make-multichoice-option
 ;   pagename-general (N_ "Style")
  ;  "d" (N_ "Report style.")
 ;   'single
 ;   (list (vector 'multi-line
 ;                 (N_ "Multi-Line")
 ;                 (N_ "Display N lines."))
 ;         (vector 'single
  ;                (N_ "Single")
 ;                 (N_ "Display 1 line.")))))

  (gnc:register-trep-option
   (gnc:make-complex-boolean-option
    pagename-general optname-common-currency
    "e" (N_ "Convert all transactions into a common currency.") #f
    #f
    (lambda (x) (gnc-option-db-set-option-selectable-by-name
         gnc:*transaction-report-options*
         pagename-general
         optname-currency
         x))
    ))

  (gnc:options-add-currency!
   gnc:*transaction-report-options* pagename-general optname-currency "f")

  (gnc:register-trep-option
   (gnc:make-simple-boolean-option
    pagename-general optname-table-export
    "g" (N_ "Formats the table suitable for cut & paste exporting with extra cells.") #f))

  ;; Accounts options

  ;; account to do report on
  (gnc:register-trep-option
   (gnc:make-account-list-option
    pagename-accounts (N_ "Accounts")
    "a" (N_ "Report on these accounts.")
    ;; select, by default, no accounts! Selecting all accounts will
    ;; always imply an insanely long waiting time upon opening, and it
    ;; is almost never useful. So we instead display the normal error
    ;; message saying "Click here", and the user knows how to
    ;; continue.
    (lambda ()
      '())
    #f #t))

  (gnc:register-trep-option
   (gnc:make-account-list-option
    pagename-accounts (N_ "Filter By...")
    "b" (N_ "Filter on these accounts.")
    (lambda ()
      ;; FIXME : gnc:get-current-accounts disappeared.
      (let* ((current-accounts '())
         (root (gnc-get-current-root-account))
         (num-accounts (gnc-account-n-children root))
         (first-account (gnc-account-nth-child root 0)))
    (cond ((not (null? current-accounts))
           (list (car current-accounts)))
          ((> num-accounts 0) (list first-account))
          (else '()))))
    #f #t))

  (gnc:register-trep-option
   (gnc:make-multichoice-option
    pagename-accounts (N_ "Filter Type")
    "c" (N_ "Filter account.")
    'none
    (list (vector 'none
          (N_ "None")
          (N_ "Do not do any filtering."))
      (vector 'include
          (N_ "Include Transactions to/from Filter Accounts")
          (N_ "Include transactions to/from filter accounts only."))
      (vector 'exclude
          (N_ "Exclude Transactions to/from Filter Accounts")
          (N_ "Exclude transactions to/from all filter accounts."))
      )))

  ;;

  (gnc:register-trep-option
   (gnc:make-multichoice-option
    pagename-accounts optname-void-transactions
    "d" (N_ "How to handle void transactions.")
    'non-void-only
    (list (vector
       'non-void-only
       (N_ "Non-void only")
       (N_ "Show only non-voided transactions."))
      (vector
       'void-only
       (N_ "Void only")
       (N_ "Show only voided transactions."))
      (vector
       'both
       (N_ "Both")
       (N_ "Show both (and include void transactions in totals).")))))

  ;; Sorting options

  (let ((options gnc:*transaction-report-options*)

        (key-choice-list
         (if (qof-book-use-split-action-for-num-field (gnc-get-current-book))
             (list (vector 'none
                           (N_ "None")
                           (N_ "Do not sort."))

                   (vector 'account-name
                           (N_ "Account Name")
                           (N_ "Sort & subtotal by account name."))

                   (vector 'account-code
                           (N_ "Account Code")
                           (N_ "Sort & subtotal by account code."))

                   (vector 'date
                           (N_ "Date")
                           (N_ "Sort by date."))

                   (vector 'corresponding-acc-name
                           (N_ "Other Account Name")
                           (N_ "Sort by account transferred from/to's name."))

                   (vector 'corresponding-acc-code
                           (N_ "Other Account Code")
                           (N_ "Sort by account transferred from/to's code."))

                   (vector 'amount
                           (N_ "Amount")
                           (N_ "Sort by amount."))

                   (vector 'description
                           (N_ "Description")
                           (N_ "Sort by description."))

                   (vector 'memo
                           (N_ "Memo")
                           (N_ "Sort by memo.")))
             (list (vector 'none
                           (N_ "None")
                           (N_ "Do not sort."))

                   (vector 'account-name
                           (N_ "Account Name")
                           (N_ "Sort & subtotal by account name."))

                   (vector 'account-code
                           (N_ "Account Code")
                           (N_ "Sort & subtotal by account code."))

                   (vector 'date
                           (N_ "Date")
                           (N_ "Sort by date."))

                   (vector 'corresponding-acc-name
                           (N_ "Other Account Name")
                           (N_ "Sort by account transferred from/to's name."))

                   (vector 'corresponding-acc-code
                           (N_ "Other Account Code")
                           (N_ "Sort by account transferred from/to's code."))

                   (vector 'amount
                           (N_ "Amount")
                           (N_ "Sort by amount."))

                   (vector 'description
                           (N_ "Description")
                           (N_ "Sort by description."))

                   (vector 'memo
                           (N_ "Memo")
                           (N_ "Sort by memo.")))))

        (ascending-choice-list
         (list
          (vector 'ascend
                  (N_ "Ascending")
                  (N_ "Smallest to largest, earliest to latest."))
          (vector 'descend
                  (N_ "Descending")
                  (N_ "Largest to smallest, latest to earliest."))))

        (subtotal-choice-list
         (list
          (vector 'none (N_ "None") (N_ "None."))
          (vector 'weekly (N_ "Weekly") (N_ "Weekly."))
          (vector 'monthly (N_ "Monthly") (N_ "Monthly."))
          (vector 'quarterly (N_ "Quarterly") (N_ "Quarterly."))
          (vector 'yearly (N_ "Yearly") (N_ "Yearly.")))))

    ;; primary sorting criterion
    (gnc:register-trep-option
     (gnc:make-multichoice-callback-option
      pagename-sorting optname-prime-sortkey
      "a" (N_ "Sort by this criterion first.")
      'account-name
      key-choice-list #f
      (lambda (x)
        (gnc-option-db-set-option-selectable-by-name
         options pagename-sorting optname-prime-subtotal
         (and (member x subtotal-enabled) #t))
        (gnc-option-db-set-option-selectable-by-name
         options pagename-sorting optname-prime-date-subtotal
         (if (member x date-sorting-types) #t #f)))))

    (gnc:register-trep-option
     (gnc:make-simple-boolean-option
      pagename-sorting (N_ "Show Full Account Name")
      "a1"
      (N_ "Show the full account name for subtotals and subtitles?")
      #f))

    (gnc:register-trep-option
     (gnc:make-simple-boolean-option
      pagename-sorting (N_ "Show Account Code")
      "a2"
      (N_ "Show the account code for subtotals and subtitles?")
      #f))

    (gnc:register-trep-option
     (gnc:make-simple-boolean-option
      pagename-sorting optname-prime-subtotal
      "c"
      (N_ "Subtotal according to the primary key?")
      #f))

    (gnc:register-trep-option
     (gnc:make-multichoice-option
      pagename-sorting optname-prime-date-subtotal
      "d" (N_ "Do a date subtotal.")
      'monthly
      subtotal-choice-list))

    (gnc:register-trep-option
     (gnc:make-multichoice-option
      pagename-sorting (N_ "Primary Sort Order")
      "e" (N_ "Order of primary sorting.")
      'ascend
      ascending-choice-list))

    ;; Secondary sorting criterion
    (gnc:register-trep-option
     (gnc:make-multichoice-callback-option
      pagename-sorting optname-sec-sortkey
      "f"
      (N_ "Sort by this criterion second.")
      'none
      key-choice-list #f
      (lambda (x)
        (gnc-option-db-set-option-selectable-by-name
         options pagename-sorting optname-sec-subtotal
         (and (member x subtotal-enabled) #t))
        (gnc-option-db-set-option-selectable-by-name
         options pagename-sorting optname-sec-date-subtotal
         (if (member x date-sorting-types) #t #f)))))

    (gnc:register-trep-option
     (gnc:make-simple-boolean-option
      pagename-sorting optname-sec-subtotal
      "g"
      (N_ "Subtotal according to the secondary key?")
      #t))

    (gnc:register-trep-option
     (gnc:make-multichoice-option
      pagename-sorting optname-sec-date-subtotal
      "h" (N_ "Do a date subtotal.")
      'yearly
      subtotal-choice-list))

    (gnc:register-trep-option
     (gnc:make-multichoice-option
      pagename-sorting (N_ "Secondary Sort Order")
      "i" (N_ "Order of Secondary sorting.")
      'ascend
      ascending-choice-list))


;;for find
 (gnc:register-trep-option
     (gnc:make-simple-boolean-option
      pagename-sorting (N_ optname-find-min)
      "j1"
      (N_ "Only show amounts greater than or equal to")
     #f))

    (gnc:register-trep-option
        (gnc:make-number-range-option pagename-sorting (N_ "Min Amount")
        "j2" (N_ "Minimum amount to show")
            100.0   ;; default
        -900000.0       ;; lower bound
        4000000.0   ;; upper bound
            2.0     ;; number of decimals
           100.0    ;; step size
        ))


    (gnc:register-trep-option
     (gnc:make-simple-boolean-option
      pagename-sorting (N_ optname-find-max)
      "j3"
      (N_ "Only show entries less than or equal")
      #f))

    (gnc:register-trep-option
        (gnc:make-number-range-option pagename-sorting (N_ "Max Amount")
        "j4" (N_ "Maximum amount to show")
            20000.0  ;; default
          -800000.0  ;; lower bound
          5000000.0 ;; upper bound
            2.0     ;; number of decimals
          100.0     ;; step size
        ))

      ;;
    (gnc:register-trep-option
    (gnc:make-complex-boolean-option
     pagename-sorting (N_ optname-find-text?)
    "k1" (N_ "Only show transactions containing the string") #f
      #f
    (lambda (x) (gnc-option-db-set-option-selectable-by-name
         gnc:*transaction-report-options*
         pagename-sorting optname-find1-field x)
        (gnc-option-db-set-option-selectable-by-name
         gnc:*transaction-report-options*
         pagename-sorting optname-find1-text
         x))
    ))

    (gnc:register-trep-option
     (gnc:make-multichoice-option
      pagename-sorting  optname-find1-field
      "k2" (N_ "Select which field or category to use")
      'description
      list-findchoices))

    (gnc:register-trep-option
     (gnc:make-string-option
      pagename-sorting optname-find1-text
      "k3" (N_ "text to look for (all transactions have a space added at front so ' a' will include all which start with a ") (N_ "")))


;
;     (let ((periodoptions gnc:*transaction-report-options*))
    (gnc:register-trep-option
;        (gnc:make-multichoice-callback-option
        (gnc:make-multichoice-option
        pagename-sorting optname-find2-operand
        "k4" (N_ "Select which field or category to use")
        'none
        list-find2-operands))
;        list-findchoices #f
;        (lambda (x)
;        (gnc-option-db-set-option-selectable-by-name
;         gnc:*transaction-report-options*
 ;        pagename-sorting (N_ text-pick-year)
 ;        (if (equal? x 'customdates) #f #t))
;        (gnc-option-db-set-option-selectable-by-name
 ;         gnc:*transaction-report-options*
;        pagename-sorting (N_ text-period)
 ;        (if (equal? x 'period) #t #f))
;        (gnc-option-db-set-option-selectable-by-name
;         periodoptions the_tab (N_ text-last)
;         (if (equal? x 'last) #t #f))
;        (gnc-option-db-set-option-selectable-by-name
 ;        periodoptions the_tab (N_ text-month)
  ;       (if (equal? x 'month) #t #f))
;        ))
;    ))
;
;


    (gnc:register-trep-option
     (gnc:make-multichoice-option
      pagename-sorting  optname-find2-field
      "k5" (N_ "Select which field or category to use")
      'description
      list-findchoices))

        (gnc:register-trep-option
     (gnc:make-string-option
      pagename-sorting optname-find2-text
      "k6" (N_ "text to look for  ") (N_ "")))

;end of section for find

 )


  ;; Display options

  (for-each
   (lambda (l)
     (gnc:register-trep-option
      (gnc:make-simple-boolean-option
       pagename-display (car l) (cadr l) (caddr l) (cadddr l))))
   ;; One list per option here with: option-name, sort-tag,
   ;; help-string, default-value
   (list
    (list optname-consolidate-case-sensitive  "a1"  (N_ "when not checked \"A\" and \"a\" are considered to be the same letter in comparing descriptions") #f)
    (list (N_ "Description")                  "c"  (N_ "Display the description?") #f)
    (list optname-descript-titlecase            "s"  (N_ "Titlecase The First Letter in Each Word") #t)
  ;; note the "memo"  option in between here
    (list (N_ "Notes")                        "d2" (N_ "Display the notes if the memo is unavailable?") #t)
    (list (N_ "Account Name")                 "e"  (N_ "Display the account name?") #t)
    (list (N_ "Use Full Account Name")        "f"  (N_ "Display the full account name?") #t)
    (list (N_ "Account Code")                 "g"  (N_ "Display the account code?") #f)
    (list (N_ "Other Account Name")           "h"  (N_ "Display the other account name?\
 (if this is a split transaction, this parameter is guessed).") #f)
    (list (N_ "Use Full Other Account Name")  "i"  (N_ "Display the full other account name?") #t)
    (list (N_ "Other Account Code")           "j"  (N_ "Display the other account code?") #f)
 ;   (list (N_ "Shares")                       "k"  (N_ "Display the number of shares?") #f)
 ;   (list (N_ "Price")                        "l"  (N_ "Display the shares price?") #f)
 ;   (list (N_ "Running Balance")              "n"  (N_ "Display a running balance?") #f)
    (list (N_ "Totals")                       "o"  (N_ "Display the totals?") #t)
    ;; note the "sign reverse" multichoice option in between here
 ;   (list (N_ "Use old running balance")      "q0"  (N_ "Use old method of computing running balance , may need for different currencies") #f)
    (list optname-days                         "q1"  (N_ "Display number of days in each period") #t)
    (list optname-show-imbalance              "r"  opthelp-show-imbalance #t)
    ; optname-descript-titlecase is being shown here instead of line d1
      ))

  (if (qof-book-use-split-action-for-num-field (gnc-get-current-book))
      (gnc:register-trep-option
       (gnc:make-simple-boolean-option
        pagename-display (N_ "Trans Number")
                                    "b2" (N_ "Display the trans number?") #f)))

  ;; Add an option to display the memo, and disable the notes option
  ;; when memos are not included.
  (gnc:register-trep-option
   (gnc:make-complex-boolean-option
    pagename-display (N_ "Memo")
    "d"  (N_ "Display the memo?") #f
    #f
    (lambda (x) (gnc-option-db-set-option-selectable-by-name
         gnc:*transaction-report-options*
         pagename-display
         (N_ "Notes")
         x))))

  (gnc:register-trep-option
   (gnc:make-multichoice-option
    pagename-display (N_ "Sign Reverses")
    "p" (N_ "Reverse amount display for certain account types.")
    'none
    (list
     (vector 'none (N_ "None") (N_ "Don't change any displayed amounts."))
     (vector 'income-expense (N_ "Income and Expense")
             (N_ "Reverse amount display for Income and Expense Accounts."))
     (vector 'credit-accounts (N_ "Credit Accounts")
             (N_ "Reverse amount display for Liability, Payable, Equity, \
Credit Card, and Income accounts.")))))


  (gnc:options-set-default-section gnc:*transaction-report-options*
                                   pagename-compare)

  gnc:*transaction-report-options*)


(define (display-date-interval-find begin end findtitle)
  (let ((begin-string (gnc-print-date begin))
        (end-string (gnc-print-date end)))
    (sprintf #f (_ "From %s To %s%s") begin-string end-string findtitle)))

(define (display-find findtitle)
    (sprintf #f (_ "%s") findtitle ))

(define (display-date-interval-columns begin end)
  (let ((begin-string (gnc-print-date begin))
        (end-string (gnc-print-date end)))
    (sprintf #f (_ "From %s To %s") begin-string end-string )))

(define (display-num-days days)
  (if (number? days)
   (_ (number->string days))
    (_ " ")))

(define (get-primary-subtotal-style options)
  (let ((bgcolor (gnc:lookup-option options
                                    (N_ "Colors")
                                    (N_ "Primary Subtotals/headings"))))
    (list 'attribute (list "bgcolor" (gnc:color-option->html bgcolor)))))

(define (get-secondary-subtotal-style options)
  (let ((bgcolor (gnc:lookup-option options
                                    (N_ "Colors")
                                    (N_ "Secondary Subtotals/headings"))))
    (list 'attribute (list "bgcolor" (gnc:color-option->html bgcolor)))))

(define (get-grand-total-style options)
  (let ((bgcolor (gnc:lookup-option options
                                    (N_ "Colors")
                                    (N_ "Grand Total"))))
    (list 'attribute (list "bgcolor" (gnc:color-option->html bgcolor)))))

(define (get-odd-row-style options)
  (let ((bgcolor (gnc:lookup-option options
                                    (N_ "Colors")
                                    (N_ "Split Odd"))))
    (list 'attribute (list "bgcolor" (gnc:color-option->html bgcolor)))))

(define (get-even-row-style options)
  (let ((bgcolor (gnc:lookup-option options
                                    (N_ "Colors")
                                    (N_ "Split Even"))))
    (list 'attribute (list "bgcolor" (gnc:color-option->html bgcolor)))))


;; check if the transaction meets the find requirements
;;

(define (filtersplits-found splits account-types-to-reverse)

    (define (splitfound? currentsplit )
        ;  (if (not (null? splits))

        (let* (
            (parent (xaccSplitGetParent currentsplit))
            (descript (xaccTransGetDescription parent))

            (account (xaccSplitGetAccount currentsplit))
            (account-type (xaccAccountGetType account))
            (damount (if (gnc:split-voided? currentsplit)
                            (xaccSplitVoidFormerAmount currentsplit)
                            (xaccSplitGetAmount currentsplit)))
            (currency (if (not (null? account))
                      (xaccAccountGetCommodity account)
                      (gnc-default-currency)))
            (report-currency (if comm-curr?
                                curr
                                currency))
            (trans-date (gnc-transaction-get-date-posted parent))

            (split-value (gnc:exchange-by-pricedb-nearest
                            (gnc:make-gnc-monetary
                            currency
                            (if (member account-type account-types-to-reverse)
                                (gnc-numeric-neg damount)
                                damount))
                            report-currency
                            ;; Use midday as the transaction time so it matches a price
                            ;; on the same day.  Otherwise it uses midnight which will
                            ;; likely match a price on the previous day
                            (timespecCanonicalDayTime trans-date)))
                )
;;;;;
        (define (found-text? which-field text-to-find ); based on entries in find-field-number
        (case which-field
        ((10) ; 'description
            (string-contains (string-append " " (string-upcase (xaccTransGetDescription parent) ) " ")  text-to-find))
        ((13) ; 'memo
            (string-contains (string-append " " (string-upcase (xaccSplitGetMemo currentsplit) ) " ")  text-to-find))
        ((14) ; 'notes
            (string-contains (string-append " " (string-upcase (xaccTransGetNotes parent) ) " ")  text-to-find))
        (( 1) ; 'account-name
            (string-contains (string-append " " (string-upcase (gnc-account-get-full-name account) ) " ")  text-to-find))
        (( 2) ;'accountcodee
            (string-contains (string-append " " (string-upcase (xaccAccountGetCode account) ) " ")  text-to-find))
        ((16 ) ; 'memo/notes
            (or (string-contains (string-append " " (string-upcase (xaccSplitGetMemo currentsplit) ) " ")  text-to-find) ;memo
            (string-contains (string-append " " (string-upcase (xaccTransGetNotes parent) ) " ")  text-to-find))) ;notes
        ((15) ; 'any
            (or (string-contains (string-append " " (string-upcase (xaccTransGetDescription parent) ) " ")  text-to-find) ;description
            (string-contains (string-append " " (string-upcase (xaccSplitGetMemo currentsplit) ) " ")  text-to-find) ; memo
            (string-contains (string-append " " (string-upcase (xaccTransGetNotes parent) ) " ")  text-to-find) ;notes
            (string-contains (string-append " " (string-upcase (gnc-account-get-full-name account) ) " ")  text-to-find) ;account-name
            (string-contains (string-append " " (string-upcase (xaccAccountGetCode account) ) " ")  text-to-find))) ; account-code
        ((11) ; 'number
            (or (string-contains (string-append " " (string-upcase (gnc-get-num-action parent currentsplit) ) " ")  text-to-find) ;num
                (if (gnc-get-num-action parent #f)
            (string-contains (string-append " " (string-upcase (gnc-get-num-action parent #f) ) " ")  text-to-find); Trans Number
             #f)))
        (( 3) ; 'date
            (string-contains (string-append " " (string-upcase (gnc-print-date (gnc-transaction-get-date-posted parent) )) " ")  text-to-find)) ;date
        (( 5) ; 'reconciled-date
                 (let* ((date (gnc-split-get-date-reconciled currentsplit))
                        (printed-date (if (equal? date (cons 0 0))
                                            ""
                                            (gnc-print-date date))))
            (string-contains (string-append " " (string-upcase printed-date) " ")  text-to-find))) ;reconciled date
        ((17) ; 'reconcile
            (string-contains (string-append " " (string-upcase (string (xaccSplitGetReconcile currentsplit)) ) " ")  text-to-find))

        ))
;;;;;;

            (or (not find-text?)
                (if find-text?
                    (let* ((found1? (found-text? find1-field  find1-text)))
                        (if (equal? find2-operand 'none)
                                found1?
                        (if (equal? find2-operand 'and)
                                (and found1? (found-text? find2-field  find2-text))
                        (if (equal? find2-operand 'or)
                                (or found1? (found-text? find2-field  find2-text))
                        (if (equal? find2-operand 'not)
                                (and found1? (not (found-text? find2-field  find2-text)))
                                #f)))))
                                #f)
                )
        )
        )
        (filter splitfound? splits )
        )

    ;

(define (find-monetary? value-monetary) ; only handles ammount - the find for text was handled earlier
        (let ((value-num (gnc:gnc-numeric-num (gnc:gnc-monetary-amount value-monetary))))
            (and
                (or (not find-min?) (>= value-num find-min ))
                (or (not find-max?) (<= value-num find-max ))
            )
))

;;
; swap hash table keys and values so can look up stored currency string and get currency
(define (hash-for-eachq x) (lambda (key val)
                        (hash-set! currency-lookup-hash val key))
                        currency-type-hash)

;; ;;;;;;;;;;;;;;;;;;;;
;; for working on consolidating descriptions
;; Here comes the big function that builds the whole table.
(define (make-split-table-comp list-thekeys options
                            primary-comp-key secondary-comp-key
                          comp-primary-subtotal-pred
                          comp-secondary-subtotal-pred
                          comp-primary-subheading-renderer
                          comp-secondary-subheading-renderer
                          comp-primary-subtotal-renderer
                          comp-secondary-subtotal-renderer)


 (let ((work-to-do (length list-thekeys))
       (work-done 0)
       (used-columns (build-column-used options)))

  (define (transaction-report-multi-rows-p options)
  ;  (eq? (gnc:option-value
  ;        (gnc:lookup-option options pagename-general (N_ "Style")))
  ;       'multi-line)
         #f
         )

  (define (transaction-report-export-p options)
    (gnc:option-value
     (gnc:lookup-option options pagename-general
       optname-table-export)))

  (define (add-other-split-rows split split-trans table used-columns
                                row-style account-types-to-reverse)
    (define (comp-other-rows-driver split split-trans parent table used-columns i)
      (let ((current-trans split-trans)
            ;(current (xaccTransGetSplit parent i))  ;needs work?
            )
        (cond ((null? current-trans) #f)
              ((equal? current-trans split-trans) ;always true - can remove?
               (comp-other-rows-driver split split-trans parent table used-columns (+ i 1)))
              (else (begin
                      (add-split-row-comp table current-trans
                                    used-columns options
                                     row-style account-types-to-reverse #f)
                      (comp-other-rows-driver split split-trans parent table used-columns
                                         (+ i 1)))))))

    (comp-other-rows-driver split split-trans (xaccSplitGetParent split)
                       table used-columns 0))

  (define (add-to-total subtotal-hash split-trans)
  ;;
  ; now to add to the sum for each column but first need to handle case where multiple currencies
                    (let (
                        (the-currency (get-currency-type split-trans))
                        (currency (hash-ref currency-lookup-hash (get-currency-type split-trans)))
                        )
                       ;; add to total for the account column
                        (let* ( (col 1))
                        (while (<= col last-column) ;; change column
                        (hash-set! subtotal-hash (string-append (number->string col) "#Vv;" the-currency)
                            (gnc:make-gnc-monetary currency
                            (gnc-numeric-add
                            (gnc:gnc-monetary-amount
                                (get-monetary split-trans col))
                            (gnc:gnc-monetary-amount
                            (hash-ref subtotal-hash (string-append (number->string col) "#Vv;" the-currency)
                                (gnc:make-gnc-monetary currency (gnc-numeric-zero))))
                                    GNC-DENOM-AUTO GNC-RND-ROUND))
                            )
                        (set! col (+ col 1))
                    )
)
))
  ;;

  (define (do-rows-with-subtotals list-thekeys
                                  table
                                  used-columns
                                  width
                                  multi-rows?
                                  odd-row?
                                  export?
                                  account-types-to-reverse
                                  comp-primary-subtotal-pred
                                  comp-secondary-subtotal-pred
                                  comp-primary-subheading-renderer
                                  comp-secondary-subheading-renderer
                                  comp-primary-subtotal-renderer
                                  comp-secondary-subtotal-renderer
                                  primary-subtotal-collector
                                  secondary-subtotal-collector
                                  total-collector)

    (gnc:report-percent-done (* 100 (/ work-done work-to-do)))
    (set! work-done (+ 1 work-done))

    (if (null? list-thekeys)
        (begin
          (gnc:html-table-append-row/markup!
           table
           def:grand-total-style
           (list
            (gnc:make-html-table-cell/size
             1 width (gnc:make-html-text (gnc:html-markup-hr)))))
      (if (gnc:option-value (gnc:lookup-option options pagename-display "Totals"))
          (comp-render-grand-total table width total-collector total-collector-hash export?)))

        (let* (
            (current-trans (car list-thekeys))

            (current-row-style (if multi-rows? def:normal-row-style
                                      (if odd-row? def:normal-row-style
                                          def:alternate-row-style)))
              (rest-trans (cdr list-thekeys))
             (next-trans (if (null? rest-trans) #f
                        (car rest-trans)))
            (split-value (add-split-row-comp ;;this currently adds a row of output and then returns amount in base column
                            table
                            current-trans
                            used-columns
                            options
                            current-row-style
                            account-types-to-reverse
                            #t)))
       ;   (if multi-rows?
       ;       (add-other-split-rows
       ;        current current-trans table used-columns def:alternate-row-style
       ;        account-types-to-reverse))

          (primary-subtotal-collector 'add  ;; change primary-subtotal collector 'add  to say
                                            ;; (add-to-total primary-subtotal-collector-hash current-trans)
                                            ;; currently adds in amount from base column , change to add each col to that
                                            ;; columns total
                                      (gnc:gnc-monetary-commodity
                                       split-value)
                                      (gnc:gnc-monetary-amount
                                       split-value))
           (add-to-total primary-subtotal-collector-hash current-trans)
          (secondary-subtotal-collector 'add  ;; currently adds in amount from base column , change to add each col to that
                                        (gnc:gnc-monetary-commodity    ;; columns total
                                         split-value)
                                        (gnc:gnc-monetary-amount
                                         split-value))
           (add-to-total secondary-subtotal-collector-hash current-trans)
           (add-to-total total-collector-hash current-trans)

          (total-collector 'add
                           (gnc:gnc-monetary-commodity split-value)
                           (gnc:gnc-monetary-amount split-value))

          (if (and comp-primary-subtotal-pred
                   (or (not next-trans)
                       (and next-trans
                           (not (comp-primary-subtotal-pred (get-primary-key current-trans) (get-primary-key next-trans))))))

              (begin
                (if comp-secondary-subtotal-pred

                    (begin
                      (comp-secondary-subtotal-renderer ;; change to show each columns total for secondary instead of just base
                       table width current-trans (get-secondary-key current-trans)
                       secondary-subtotal-collector
                       secondary-subtotal-collector-hash
                       def:secondary-subtotal-style used-columns export?)
                      (set! secondary-subtotal-collector-hash (make-hash-table))
                      (secondary-subtotal-collector 'reset #f #f)))

                (comp-primary-subtotal-renderer table width current-trans (get-primary-key current-trans)
                                           primary-subtotal-collector
                                           primary-subtotal-collector-hash
                                           def:primary-subtotal-style used-columns
                                           export?)
                (set! primary-subtotal-collector-hash (make-hash-table))
                (primary-subtotal-collector 'reset #f #f)

                (if next-trans
                    (begin
                      (comp-primary-subheading-renderer
                       next-trans (get-primary-key next-trans) table width def:primary-subtotal-style used-columns)

                      (if comp-secondary-subtotal-pred
                          (comp-secondary-subheading-renderer
                           next-trans (get-secondary-key next-trans)
                           table
                           width def:secondary-subtotal-style used-columns)))))

              (if (and comp-secondary-subtotal-pred
                       (or (not next-trans)
                           (and next-trans
                                (not (comp-secondary-subtotal-pred
                                      (get-secondary-key current-trans) (get-secondary-key next-trans))))))
                  (begin (comp-secondary-subtotal-renderer
                          table width current-trans (get-secondary-key current-trans)
                          secondary-subtotal-collector
                          secondary-subtotal-collector-hash
                          def:secondary-subtotal-style used-columns export?)
                         (set! secondary-subtotal-collector-hash (make-hash-table))
                         (secondary-subtotal-collector 'reset #f #f)
                         (if next-trans
                             (comp-secondary-subheading-renderer
                              next-trans (get-secondary-key next-trans) table width
                              def:secondary-subtotal-style used-columns)))))

          (do-rows-with-subtotals rest-trans
                                  table
                                  used-columns
                                  width
                                  multi-rows?
                                  (not odd-row?)
                                  export?
                                  account-types-to-reverse
                                  comp-primary-subtotal-pred
                                  comp-secondary-subtotal-pred
                                  comp-primary-subheading-renderer
                                  comp-secondary-subheading-renderer
                                  comp-primary-subtotal-renderer
                                  comp-secondary-subtotal-renderer
                                  primary-subtotal-collector
                                  secondary-subtotal-collector
                                  total-collector))))


  (let* ((table (gnc:make-html-table))
         (width (+ columns-headings 0))
         (multi-rows? (transaction-report-multi-rows-p options))
     (export? (transaction-report-export-p options))
         (account-types-to-reverse
          (get-account-types-to-reverse options)))

    (gnc:html-table-set-col-headers!
     table
    (make-heading-list used-columns options))

    (if show-days?
     (make-heading-days table def:primary-subtotal-style))
    (if scaled?
     (make-heading-scale table def:primary-subtotal-style))
    ;;     (gnc:warn "Split-trans:" split-transs)
    (if (not (null? list-thekeys))
        (begin
          (set! amount-total-hash (make-hash-table))
          (if comp-primary-subheading-renderer  ;;print heading above the items we will print (be they transactions or accounts or ...)
              (comp-primary-subheading-renderer
               (car list-thekeys) (get-primary-key (car list-thekeys)) table width def:primary-subtotal-style used-columns))
          (if comp-secondary-subheading-renderer
              (comp-secondary-subheading-renderer
               (car list-thekeys) (get-secondary-key (car list-thekeys)) table width def:secondary-subtotal-style used-columns))
         (set! primary-subtotal-collector-hash (make-hash-table))
         (set! secondary-subtotal-collector-hash (make-hash-table))
         (set! total-collector-hash (make-hash-table))
          (do-rows-with-subtotals  list-thekeys table used-columns width
                                  multi-rows? #t
                                  export?
                                  account-types-to-reverse
                                  comp-primary-subtotal-pred
                                  comp-secondary-subtotal-pred
                                  comp-primary-subheading-renderer
                                  comp-secondary-subheading-renderer
                                  comp-primary-subtotal-renderer
                                  comp-secondary-subtotal-renderer
                                  (gnc:make-commodity-collector)
                                  (gnc:make-commodity-collector)
                                  (gnc:make-commodity-collector))))

    table)))



;; end of the big function for composite / consolidating

;; ;;;;;;;;;;;;;;;;;;;;
;; Here comes the renderer function for this report.
(define (trep-renderer report-obj)

  (define options (gnc:report-options report-obj))

  (define (opt-val section name)
    (gnc:option-value
     (gnc:lookup-option options section name)))

  ;;(define (get-other-account-names account-list)
  ;;  ( map (lambda (acct)  (gnc-account-get-full-name acct)) account-list))

  (define (is-filter-member split account-list)
    (let* ((txn (xaccSplitGetParent split))
           (splitcount (xaccTransCountSplits txn)))

      (cond
        ;; A 2-split transaction - test separately so it can be optimized
        ;; to significantly reduce the number of splits to traverse
        ;; in guile code
        ((= splitcount 2)
         (let* ((other      (xaccSplitGetOtherSplit split))
                (other-acct (xaccSplitGetAccount other)))
               (member other-acct account-list)))

        ;; A multi-split transaction - run over all splits
        ((> splitcount 2)
         (let ((splits (xaccTransGetSplitList txn)))

                ;; Walk through the list of splits.
                ;; if we reach the end, return #f
                ;; if the 'this' != 'split' and the split->account is a member
                ;; of the account-list, then return #t, else recurse
                (define (is-member splits)
                  (if (null? splits)
                      #f
                      (let* ((this (car splits))
                             (rest (cdr splits))
                             (acct (xaccSplitGetAccount this)))
                        (if (and (not (eq? this split))
                                 (member acct account-list))
                            #t
                            (is-member rest)))))

                (is-member splits)))

        ;; Single transaction splits
        (else #f))))


    ;; for composite
    ;;
    (define comp-comp-funcs-assoc-list
    ;; Defines the different sorting keys, together with the
    ;; subtotal functions. Each entry: (cons
    ;; 'sorting-key-option-value (vector 'query-sorting-key
    ;; subtotal-function subtotal-renderer))
;;  (let* ((used-columns (build-column-used options))) ;; tpo: gives unbound variable options?
    (let* ((used-columns (build-column-used (gnc:report-options report-obj))))
      (list (cons 'account-name  (vector
                                  (list SPLIT-ACCT-FULLNAME)
                                  comp-split-account-full-name-same-p
                                  comp-render-account-subheading
                                  comp-render-account-subtotal))
            (cons 'account-code  (vector
                                  (list SPLIT-ACCOUNT ACCOUNT-CODE-)
                                  comp-split-account-code-same-p
                                  comp-render-account-subheading
                                  comp-render-account-subtotal))
            (cons 'date          (vector
                                  (list SPLIT-TRANS TRANS-DATE-POSTED)
                                  #f #f #f))
            (cons 'corresponding-acc-name
                                 (vector
                                  (list SPLIT-CORR-ACCT-NAME)
                                  comp-split-same-corr-account-full-name-p
                                  comp-render-corresponding-account-subheading
                                  comp-render-corresponding-account-subtotal))
            (cons 'corresponding-acc-code
                                 (vector
                                  (list SPLIT-CORR-ACCT-CODE)
                                  comp-split-same-corr-account-code-p
                                  comp-render-corresponding-account-subheading
                                  comp-render-corresponding-account-subtotal))
            (cons 'amount        (vector (list SPLIT-VALUE) #f #f #f))
            (cons 'description   (vector (list SPLIT-TRANS TRANS-DESCRIPTION) #f #f #f))
            (cons 'memo          (vector (list SPLIT-MEMO) #f #f #f))
            (cons 'none          (vector '() #f #f #f)))))

  (define comp-date-comp-funcs-assoc-list
    ;; Extra list for date option. Each entry: (cons
    ;; 'date-subtotal-option-value (vector subtotal-function
    ;; subtotal-renderer))
    (list
     (cons 'none (vector #f #f #f))
     (cons 'weekly (vector comp-split-same-week-p comp-render-week-subheading
                            comp-render-week-subtotal))
     (cons 'monthly (vector comp-split-same-month-p comp-render-month-subheading
                            comp-render-month-subtotal))
     (cons 'quarterly (vector comp-split-same-quarter-p comp-render-quarter-subheading
                            comp-render-quarter-subtotal))
     (cons 'yearly (vector comp-split-same-year-p comp-render-year-subheading
                           comp-render-year-subtotal))))

  (define (comp-get-subtotalstuff-helper
           name-sortkey name-subtotal name-date-subtotal
           comp-index date-index)
    ;; The value of the sorting-key multichoice option.
    (let ((sortkey (opt-val pagename-sorting name-sortkey)))
      (if (member sortkey date-sorting-types)
          ;; If sorting by date, look up the value of the
          ;; date-subtotalling multichoice option and return the
          ;; corresponding funcs in the assoc-list.
          (vector-ref
           (cdr (assq (opt-val pagename-sorting name-date-subtotal)
                      comp-date-comp-funcs-assoc-list))
           date-index)
          ;; For everything else: 1. check whether sortkey has
          ;; subtotalling enabled at all, 2. check whether the
          ;; enable-subtotal boolean option is #t, 3. look up the
          ;; appropriate funcs in the assoc-list.
          (and (member sortkey subtotal-enabled)
               (and (opt-val pagename-sorting name-subtotal)
                    (vector-ref
                     (cdr (assq sortkey comp-comp-funcs-assoc-list))
                     comp-index))))))

  (define (comp-get-query-sortkey sort-option-value)
    (vector-ref
     (cdr (assq sort-option-value comp-comp-funcs-assoc-list))
     0))

  (define (comp-get-subtotal-pred
           name-sortkey name-subtotal name-date-subtotal)
    (comp-get-subtotalstuff-helper
     name-sortkey name-subtotal name-date-subtotal
     1 0))

  (define (comp-get-subheading-renderer
           name-sortkey name-subtotal name-date-subtotal)
    (comp-get-subtotalstuff-helper
     name-sortkey name-subtotal name-date-subtotal
     2 1))

  (define (comp-get-subtotal-renderer
           name-sortkey name-subtotal name-date-subtotal)
    (comp-get-subtotalstuff-helper
     name-sortkey name-subtotal name-date-subtotal
     3 2))


    ;;


    (define timeperiods
        (list
        (cons 'weekly 1)
        (cons 'monthly 2)
        (cons 'quarterly 3)
        (cons 'yearly 4)
        (cons 'none 5)
        ))

;;
(define sort-key-number
    (list
    (cons 'none 0)
    (cons 'account-name 1)
    (cons 'account-code 2)
    (cons 'date         3)
    (cons 'exact-time     4)
    (cons 'reconciled-date 5)
    (cons 'register-order 6)
    (cons 'corresponding-acc-name 7)
    (cons 'corresponding-acc-code 8)
    (cons 'amount         9)
    (cons 'description  10)
    (cons 'memo         13)
    )
  )


(define (get-sort-type primary-key secondary-key)
        (if (not (equal? primary-key 'amount))
                        (if (equal? secondary-key 'amount)
                                    'primary_amount
                                    'primary_secondary)
                        (if (equal? secondary-key 'amount)
                                    'amount_amount
                                    'amount_secondary)
    ))


(define comp-sort-list
    ;; List for sorting consolidated transactions. Each entry: (cons
    ;; 'type-of-comparison (vector get-first-variable compare-first-variable compare-first-if-normal-order
    ;;   compare-first-variable-if-reverse-sort get-second-variable compare-second-variable
    ;;   compare-second-standard-oder  compare-second-variable-reverse-order ))
    (list
    ;;      comparing                how to get variable           match      ascend            descend
    (cons 'primary_secondary (vector get-primary-key             string-ci=? string-ci<?     string-ci>?
                                     get-secondary-key           string-ci=? string-ci<?     string-ci>? ))

    (cons 'primary_amount    (vector get-primary-key             string-ci=? string-ci<?     string-ci>?
                                     get-array-value-num-base     =           <               >       ))

    (cons 'amount_secondary  (vector get-array-value-num-base     =           <               >
                                      get-secondary-key           string-ci=? string-ci<?     string-ci>?))

    (cons 'amount_amount     (vector get-array-value-num-base     =           <               >
                                     get-array-value-num-base     =           <               >       )))
)

(define (comp-sort-helper sort-option-value col-index)
    (vector-ref
     (cdr (assq sort-option-value comp-sort-list))
     col-index))


;;
(define (get-the-transactions splits account-full-name? account-code? consolidate-case-sensitive? primary-comp-key secondary-comp-key)
    ;; get-the-transactions  takes the query results and stores them in hash tables named payee-hash
    ;;  and payee-account-guid-hash - consolidates transactions having same description and or account name
    ;;
(define (set-date-tm trans-date-tm sort-date-type )
    (case sort-date-type
        ((5) ; 'none
            (set-tm:mday trans-date-tm 1 )
            )
        ((1) ; 'weekly
            (let ((day (gnc:day-of-week trans-date-tm)))
                (set! trans-date-tm (gnc:decrement-date trans-date-tm day ))
            ))
        ((2) ; 'monthly
            (set-tm:mday  trans-date-tm 1))
        ((3) ; 'quarterly
            (begin
                (set-tm:mday trans-date-tm 1 )
                (case (quotient (tm:mon trans-date-tm) 3)
                    ((0) (set-tm:mon trans-date-tm 0)  )
                    ((1) (set-tm:mon trans-date-tm 3 ) )
                    ((2) (set-tm:mon trans-date-tm 6) )
                    ((3) (set-tm:mon trans-date-tm 9))
                    )
                ))
        ((4) ; 'yearly
            (begin
                (set-tm:mday  trans-date-tm 1)
                (set-tm:mon  trans-date-tm 0))
            )
        )
        trans-date-tm
    )
;;


  (define (composite-sort key split column-vector)

    (case key
        ((0) ; 'none
             " "
            )
        ((1)  ; 'account-name
          (let (
                (account (xaccSplitGetAccount split)))
                (if account-full-name?
                    (string-append  "#Yv;" (gnc-account-get-full-name account) )
                    (string-append  (gnc-account-get-full-name account) "#Yv;" (xaccAccountGetName account))))
            )
        ((2)  ; 'account-code
            (let (
                (account (xaccSplitGetAccount split)))
                (if account-full-name?
                    (string-append  (xaccAccountGetCode account)  " " (gnc-account-get-full-name account) )
                    (string-append  (xaccAccountGetCode account) " " (xaccAccountGetName account)))
             )
            )
        ((3)  ; 'date
            (let* (
                (parent (xaccSplitGetParent split))
                (trans-date (gnc-transaction-get-date-posted parent))
                (tm (gnc:timepair->date trans-date))
                (date-string (if (> 5  sort-date-type)
                        (strftime "%Y%m%d" (set-date-tm tm sort-date-type))
                        "")))
            date-string)
            )
        ((4)  ; 'exact-time
             " "
            )
        ((5)  ; 'reconciled-date
            (let* ((date (gnc-split-get-date-reconciled split))
                (primary-type (if (equal? primary-comp-key 5)
                                        (cdr (assq (opt-val pagename-sorting optname-prime-date-subtotal)  timeperiods  ))
                                        5)) ;no date requirement
                (sec-type (if (equal? secondary-comp-key 5)
                                    (assq-ref  timeperiods (opt-val pagename-sorting optname-sec-date-subtotal) )
                                        5)) ;no date requirement
                (sort-date-type (min primary-type sec-type ))
                (date-string
                    (if (equal? date (cons 0 0))
                        " "
                        (strftime "%Y%m%d" (set-date-tm (gnc:timepair->date date) sort-date-type))
                    )))
                date-string)
                )
        ((6)  ; 'register-order
             " "
            )
        ((7)  ; 'corresponding-acc-name   currently not connected
             " "
            )
        ((8)  ; 'corresponding-acc-code  currently not connected
             " "
            )
        ((9)  ; 'amount     - handled in another part of program
             " "
            )
        ((10) ; 'description
            (let* (
                (parent (xaccSplitGetParent split))
                (descript (if consolidate-case-sensitive?
                        (xaccTransGetDescription parent)
                        (string-capitalize (xaccTransGetDescription parent))))
                )
                (if (< 0 (string-length  descript))
                    descript
                    " ")
                )
            )
        ((11) ; 'number
             " "
            )
        ((12) ; 't-number
             " "
            )
        ((13) ; 'memo
            (let* (
                (parent (xaccSplitGetParent split))
                (memo  (xaccSplitGetMemo split))
                (notes (xaccTransGetNotes parent))
                (note-memo (if (< 0 (string-length  memo))
                    memo
                    (if (and (< 0 (string-length  notes)) (used-notes column-vector))
                    notes
                    " ")))
                )
                (if consolidate-case-sensitive?
                    note-memo
                    (string-upcase note-memo))
            ))
    ))



    (let*
        ((split (car splits))
        (rest (cdr splits))
        (parent (xaccSplitGetParent split))
        (account (xaccSplitGetAccount split))
;        (account-other (xaccSplitGetOtherSplit split))
        (account-guid (gncAccountGetGUID account))
         (trans-guid (gncTransGetGUID parent ))
        (acctfull (gnc-account-get-full-name account))
        (acctgetnam  (xaccAccountGetName account))

;       (acct-comm (xaccAccountGetCommodity account))
;        (shares (xaccSplitGetAmount split))
;        (comodmul  (gnc-commodity-numeric->string acct-comm shares))
;        (transcurr (xaccTransGetCurrency parent))
;       (shareprice  (xaccSplitGetSharePrice split))

        (column-vector (build-column-used options))
        (descript-raw  (if (used-description column-vector)
                        (xaccTransGetDescription parent)
                        " "))
        (guids+description (list
                trans-guid
                account-guid
                descript-raw)
                )

        (descript (if consolidate-case-sensitive?
                    descript-raw
                    (string-upcase descript-raw)
                    ))

        (currency (if (not (null? account))
                       (xaccAccountGetCommodity account)
                       (gnc-default-currency)))
        (damount (if (gnc:split-voided? split)
                     (xaccSplitVoidFormerAmount split)
                     (xaccSplitGetAmount split)))
        (report-currency (if (opt-val pagename-general optname-common-currency)
                   (opt-val pagename-general optname-currency)
                   currency))
        (account-type (xaccAccountGetType account))
        (account-types-to-reverse    (get-account-types-to-reverse options))
        (trans-date (gnc-transaction-get-date-posted parent))
        (member-reverse-sign (if (member account-type account-types-to-reverse)
                                "r"
                                ""))
        (split-value (gnc:exchange-by-pricedb-nearest
               (gnc:make-gnc-monetary
                currency
            (if (equal? member-reverse-sign "r")
                (gnc-numeric-neg damount)
                damount))
               report-currency
               ;; Use midday as the transaction time so it matches a price
               ;; on the same day.  Otherwise it uses midnight which will
               ;; likely match a price on the previous day
               (timespecCanonicalDayTime trans-date)))
        (split-value-mon (gnc:gnc-monetary-amount split-value))

        ; to print weekly, quarterly ...
        (tm (gnc:timepair->date (gnc-transaction-get-date-posted parent)))
        (date-string (if (> 5 sort-date-type)
                        (strftime "%Y%m%d" (set-date-tm tm sort-date-type))
                        ""))

        ; use composite sort to read into primary and secondary sort the item, such as description
        ; can not convert everything to upper case here because the marker #Yv; is used in account code
        (primary-sort (composite-sort primary-comp-key split column-vector))
        (secondary-sort (composite-sort secondary-comp-key split column-vector))

    ;
    ;

    ;     (notes (xaccTransGetNotes parent))
    ;     (num (gnc-get-num-action parent split))


        (acct-code (if account-code?
                    (string-append (xaccAccountGetCode account) " ")
                    ""))

        (memo (if (used-memo column-vector)
                (let ((memo (xaccSplitGetMemo split)))
                    (if (and (equal? memo "") (used-notes column-vector))
                        (xaccTransGetNotes parent)
                        memo))
                ""))
        (memo (if consolidate-case-sensitive?
                    memo
                    (string-upcase memo)))

        (acctnamecode (if (or (used-account-name column-vector) (used-account-code column-vector))
                        (account-namestring account
                                (used-account-code      column-vector)
                                (used-account-name      column-vector)
                                (used-account-full-name column-vector))
                                ""))
        (acctothernamcod  (if (or (used-other-account-name column-vector) (used-other-account-code column-vector))
                        (account-namestring (xaccSplitGetAccount
                                   (xaccSplitGetOtherSplit split))
                                   (used-other-account-code      column-vector)
                                   (used-other-account-name      column-vector)
                                   (used-other-account-full-name column-vector))
                                   "")
                )
        (hashed-currency (hash-ref currency-type-hash report-currency currency-type-str)) ; in case transactions with same description have different currencies

        (hashkey (string-append  primary-sort "#Yw;" secondary-sort "#Yx;" date-string "#Yy;"
                         descript "#Yz;"
            acctnamecode "#Zy;" acct-code "#Zx;" acctothernamcod "#Zw;" memo "#Zv;" member-reverse-sign "#Zu;" hashed-currency  ))
         )
        (total-payee-hash-add! payee-hash hashkey split-value-mon payee-account-guid-hash guids+description)
        (if (equal? currency-type-str hashed-currency); if we used the current number - add to hash and prepare new number
                (begin
                (hash-set! currency-type-hash report-currency hashed-currency )
                (set! currency-type-num (+ 1 currency-type-num))
                (set! currency-type-str (number->string currency-type-num))
        ))
        (if (> (length rest) 0)
            (get-the-transactions rest account-full-name? account-code? consolidate-case-sensitive? primary-comp-key secondary-comp-key ))
        )
    )
;;end of section for consolidate
    (define find-field-number
    (list
    (cons 'none 0)
    (cons 'account-name 1)
    (cons 'account-code 2)
    (cons 'date         3)
    (cons 'corresponding-acc-name 7)
    (cons 'corresponding-acc-code 8)
    (cons 'amount         9)
    (cons 'description  10)
    (cons 'memo         13)
    (cons 'notes        14)
    (cons 'any          15)
    (cons 'memo/notes   16)
    (cons 'reconcile    17)
    )
  )

  (let* ((document (gnc:make-html-document))
    (c_account_1 (opt-val pagename-accounts "Accounts"))
    (c_account_2 (opt-val pagename-accounts "Filter By..."))
    (filter-mode (opt-val pagename-accounts "Filter Type"))
    (report-title (opt-val
                       pagename-general
                       gnc:optname-reportname)))


(define (store-period-values column list_of_trans scaling-mul-val scaling-div-val)
;; transfers results for a single period from hash table into a column in the amounts-array along with
;; storing the guid in the same array location in the guid-array.  Entries are put on the same row as
;; the description or account name from earlier periods by using the hash table pointer-hash
;;  new names are added to the hash table and added at the bottom of the array

(if  (not (null? splits))
(for-each
    (lambda (split-trans)
        (let* (
        (thekey (car split-trans))
        (guids+description (hash-ref payee-account-guid-hash thekey ))

        (report-currency (hash-ref currency-lookup-hash (get-currency-type split-trans)))
        (currency-frac (gnc-commodity-get-fraction report-currency))
        (value
            (if (= 1 scaling-mul-val)
                (get-split-value-numer split-trans)
                (gnc-numeric-mul
                    (gnc:make-gnc-numeric (inexact->exact (* 100 scaling-mul-val)) 100)
                            (get-split-value-numer split-trans)  currency-frac GNC-RND-ROUND)))
        (split-value (gnc:make-gnc-monetary report-currency
            (if (= 1 scaling-div-val)
                value
            (gnc-numeric-div value
                (gnc:make-gnc-numeric (inexact->exact (* 100 scaling-div-val)) 100)
                      currency-frac GNC-RND-ROUND))))
        (split-value-coll (if (get-reverse-sign? split-trans)
                (gnc:make-gnc-monetary report-currency (gnc-numeric-neg (gnc:gnc-monetary-amount split-value)))
                split-value))
        (row (hash-ref pointer-hash thekey row-number))
        )
        (array-set! amounts-array split-value row column)
        (array-set! guid-array guids+description row column)
        (if (eq? row row-number)    ; if we wrote it on row-number than we wrote on a new row,
            (begin                    ;  set counter "row-number" to point to next unused line and store info about thekey
                (hash-set! pointer-hash thekey row-number ) ;store key and the row number where this keys data is stored
                ; store this lines key which contains description and or account name etcetra
                (array-set! amounts-array report-currency row-number 0 )
                  ;store guid for account name along with how user stored name
                (array-set! guid-array guids+description row-number 0 )
                (set! row-number  (+ 1 row-number))
          ))
        ))
        list_of_trans
))
)


(define (get-periods-results begin-date end-date)
;; based on transaction.scm  this routine is basically the transaction.scm program
;; converted to a define statement.  It
;; queries gnucash then stores the results in hash table by calling get-the-transactions
;; the store-period-values routine will then transfer this periods results to a columnn an array
  (let* (
    (primary-key (opt-val pagename-sorting optname-prime-sortkey))
    (primary-order (opt-val pagename-sorting "Primary Sort Order"))
    (secondary-key (opt-val pagename-sorting optname-sec-sortkey))
    (secondary-order (opt-val pagename-sorting "Secondary Sort Order"))

;for consolidate
    (primary-comp-key  (cdr (assq primary-key  sort-key-number  )))
    (secondary-comp-key  (cdr (assq secondary-key  sort-key-number  )))
    (consolidate-case-sensitive? (opt-val pagename-display optname-consolidate-case-sensitive))

    (void-status (opt-val pagename-accounts optname-void-transactions))

        (query (qof-query-create-for-splits)))

    ;;(gnc:warn "accts in trep-renderer:" c_account_1)
    ;;(gnc:warn "Report Account names:" (get-other-account-names c_account_1))

    (if (not (or (null? c_account_1) (and-map not c_account_1)))
        (begin
          (qof-query-set-book query (gnc-get-current-book))
          ;;(gnc:warn "query is:" query)
          (xaccQueryAddAccountMatch query
                                       c_account_1
                                       QOF-GUID-MATCH-ANY QOF-QUERY-AND)
          (xaccQueryAddDateMatchTS
           query #t begin-date #t end-date QOF-QUERY-AND)
          (qof-query-set-sort-order query
                    (comp-get-query-sortkey primary-key)
                    (comp-get-query-sortkey secondary-key)
                    '())

          (qof-query-set-sort-increasing query
                                         (eq? primary-order 'ascend)
                                         (eq? secondary-order 'ascend)
                                         #t)

      (case void-status
       ((non-void-only)
        (gnc:query-set-match-non-voids-only! query (gnc-get-current-book)))
       ((void-only)
        (gnc:query-set-match-voids-only! query (gnc-get-current-book)))
       (else #f))
        ; (set! splits '())    ;may be able to delete
          (set! splits (qof-query-run query))

          ;;(gnc:warn "Splits in trep-renderer:" splits)

      ;;(gnc:warn "Filter account names:" (get-other-account-names c_account_2))

      ;;This should probably a cond or a case to allow for different filter types.
      ;;(gnc:warn "Filter Mode: " filter-mode)
      (if (eq? filter-mode 'include)
          (begin
        ;;(gnc:warn "Including Filter Accounts")
        (set! splits (filter (lambda (split)
                       (is-filter-member split c_account_2))
                     splits))
        )
          )

      (if (eq? filter-mode 'exclude)
          (begin
        ;;(gnc:warn "Excluding Filter Accounts")
        (set! splits (filter (lambda (split)
                       (not (is-filter-member split c_account_2)))
                     splits))
        )
          )


;; for find text
(if (and (not (null? splits)) find-text?)
    (let(
        (account-types-to-reverse    (get-account-types-to-reverse options)))
        (set! splits (filtersplits-found splits account-types-to-reverse))))
    ))

    (qof-query-destroy query)

;;   for composite transaction corr

    (if  (not (null? splits))
        (begin

        (hash-clear! payee-hash  )
        (hash-clear! payee-account-guid-hash)

         (get-the-transactions splits  ;; routine to consolidate the transactions
                        (opt-val pagename-sorting (N_ "Show Full Account Name")) ;for sort subheadings , not for display on each trans
                        (opt-val pagename-sorting (N_ "Show Account Code")) ; not the display tab flag, used for sort headings
                        consolidate-case-sensitive?
                        primary-comp-key secondary-comp-key
                        )

        (set! list_of_trans (hash-map->list cons payee-hash)) ;list of all of the transactions in the period


        ; swap hash table keys and values so can look up stored currency string and get currency
        (hash-for-each  (lambda (key val)
                        (hash-set! currency-lookup-hash val key))
                        currency-type-hash)
    ))
    )
    );; end of define - get-periods-results

(define (calculate-delta list-thekeys)
    (for-each
        (lambda (trans)
    (let (
        (row (get-row-in-array trans)))
    (array-set! amounts-array
            (gnc-numeric-sub
            (gnc:gnc-monetary-amount (get-monetary trans 1))
            (gnc:gnc-monetary-amount (get-monetary trans 2)) GNC-DENOM-AUTO GNC-RND-ROUND)
            row 3)))
    list-thekeys)
)


    (gnc:report-starting reportname)
(if (not (or (null? c_account_1) (and-map not c_account_1)))
        (begin
    (let* (
    ;; step 4 of 4 needed for gnctimeperiod-utilities
;; the let needs to be a let*
;; may need to change op-value to get-option
        (whichperiod-val (opt-val the_tab text-whichperiod))

        (cust-start-date-tp    (gnc:timepair-start-day-time
                                    (gnc:date-option-absolute-time
                                    (opt-val the_tab
                                        custom-from-date))))

        (cust-end-date-tp    (gnc:timepair-end-day-time
                                    (gnc:date-option-absolute-time
                                    (opt-val the_tab
                                        custom-to-date))))
        (year-val     (opt-val  the_tab text-pick-year))
        (period-val   (opt-val  the_tab text-period))
        (last-val   (opt-val the_tab text-last))
        (month-val   (opt-val the_tab text-month))
        (datelist   (gnc:getdates
            (list whichperiod-val year-val period-val last-val month-val)) )
        ;;
        ;; replace following two names with your names and comment out your old definitions
        (begindate    (if (equal? whichperiod-val 'customdates )
                            cust-start-date-tp
                            (car datelist)))


        (enddate      (if (equal? whichperiod-val 'customdates )
                            cust-end-date-tp
                            (cadr datelist)))

        (list-base-period (gnc:getdatedelta   ;use to get number of days in base
                            (list begindate enddate 'none)))

;; end of section 4 needed for using gnctimeperiod-utilities
;;
  ;      (begindate (gnc:timepair-start-day-time
 ;                   (gnc:date-option-absolute-time
  ;                   (opt-val pagename-general "Start Date"))))
  ;      (enddate (gnc:timepair-end-day-time
  ;                (gnc:date-option-absolute-time
  ;                 (opt-val pagename-general "End Date"))))

; for comparison period

        (deltas-val (opt-val pagename-compare text-compare-divide))
        (whichperiod-val2 (opt-val pagename-compare text-whichcompareperiod))
        (cust-start-date2-tp    (gnc:timepair-start-day-time
                                    (gnc:date-option-absolute-time
                                    (opt-val pagename-compare
                                        custom-from-date))))

        (cust-end-date2-tp    (gnc:timepair-end-day-time
                                    (gnc:date-option-absolute-time
                                    (opt-val pagename-compare
                                        custom-to-date))))
        (year-val2     (opt-val  pagename-compare text-pick-year))
        (period-val2   (opt-val  pagename-compare text-period))
        (last-val2   (opt-val pagename-compare text-last))
        (month-val2   (opt-val pagename-compare text-month))
        (datelist2   (gnc:getdates
            (list whichperiod-val2 year-val2 period-val2 last-val2 month-val2)) )
       (average-val2   (opt-val pagename-compare text-average))
       (averagelist2   (getdates-average average-val2 (opt-val pagename-compare text-exclude-average)))
        ;;
        ;; replace following two names with your names and comment out your old definitions
        (begindate2    (if (equal? whichperiod-val2 'customdates )
                            cust-start-date2-tp
                            (if (equal? whichperiod-val2 'average )
                              (car averagelist2)
                               (car datelist2))))


        (enddate2      (if (equal? whichperiod-val2 'customdates )
                            cust-end-date2-tp
                            (if (equal? whichperiod-val2 'average )
                               (cadr averagelist2)
                               (cadr datelist2))))
        (list-of-periods (gnc:getdatedelta
                            (list begindate2 enddate2 deltas-val)))

;; end for comparison period

        (primary-key (opt-val pagename-sorting optname-prime-sortkey))
        (primary-order (opt-val pagename-sorting "Primary Sort Order"))
        (secondary-key (opt-val pagename-sorting optname-sec-sortkey))
        (secondary-order (opt-val pagename-sorting "Secondary Sort Order"))

;for consolidate
        (primary-comp-key  (cdr (assq primary-key  sort-key-number  )))
        (secondary-comp-key  (cdr (assq secondary-key  sort-key-number  )))
        (consolidate-case-sensitive? (opt-val pagename-display optname-consolidate-case-sensitive))

;for compare
    (compare? (opt-val pagename-compare optname-compare?))
    (base?  (or (not (opt-val pagename-compare optname-no-base?))
                (not (opt-val pagename-compare optname-compare?))))
        )

    (set! show-days? (opt-val pagename-display optname-days))

    (set! show-average? (opt-val pagename-compare optname-show-average?))

;for consolidate
    (set! comm-curr? (opt-val pagename-general optname-common-currency))
    (set! curr        (opt-val pagename-general optname-currency))
    (set! sort-date-type (let (
                    ( primary-type (if (equal? primary-key 'date)
                                        (cdr (assq (opt-val pagename-sorting optname-prime-date-subtotal)  timeperiods  ))
                                        5)) ;no date requirement
                    (sec-type (if (equal? secondary-key 'date)
                                    (assq-ref  timeperiods (opt-val pagename-sorting optname-sec-date-subtotal) )
                                        5)) ;no date requirement
                             )
                    (min primary-type sec-type )))
;;end section for consolidate

;;for scaling
    (set! scale-op-val      (opt-val the_tab "Scale Results"))
    (set! scale-num-val  (opt-val the_tab "Scale Number Option"))


;; for compare period scaling
    (set! scale-op-val2      (opt-val pagename-compare "Scale Results"))
    (set! scale-num-val2  (opt-val pagename-compare "Scale Number Option"))

    (set! compare-scale-automatically? (opt-val pagename-compare optname-scale-automatically?))
    (set! compare-scale-to-val         (opt-val pagename-compare optname-scale-to))
    (set! scaled? (if (or (not (= 1 scale-num-val)) (not (= 1 scale-num-val2)) compare-scale-automatically?)
                    #t
                    #f))

     ;; for find option
     ;for find
    (set! find-text? (opt-val pagename-sorting optname-find-text?))
    (set! find1-field (cdr (assq (opt-val pagename-sorting optname-find1-field )  find-field-number  )))
    (set! find2-operand (opt-val pagename-sorting optname-find2-operand))
    (set! find1-text  (string-upcase (opt-val pagename-sorting optname-find1-text)))
    (set! find2-field (cdr (assq (opt-val pagename-sorting optname-find2-field )  find-field-number  )))
    (set! find2-text  (string-upcase (opt-val pagename-sorting optname-find2-text)))

    (set! find-min? (opt-val pagename-sorting optname-find-min))
    (set! find-max? (opt-val pagename-sorting optname-find-max))
    (set! find-min  (opt-val pagename-sorting "Min Amount"))
    (set! find-max  (opt-val pagename-sorting "Max Amount"))
    (set! description-titlecase? (opt-val pagename-display optname-descript-titlecase))
    (set! do-find? (or find-text? find-min? find-max?)    )
    (set! do-findamount? (or find-min? find-max?))
    (set! findtitle "")
    (if (or find-text? find-min? find-max?)
        (let* (     (report-currency (if comm-curr?
                                        curr
                                        (gnc-default-currency))))

        (begin
        (if find-text?
            (begin
            (set! findtitle (string-append findtitle text-containing find1-text))
            (if (not (equal? find2-operand 'none))
                (set! findtitle (string-append findtitle " "
                (if (equal? find2-operand 'and)
                text-and
                (if (equal? find2-operand 'or)
                text-or
                (if (equal? find2-operand 'not)
                text-but-not
                "")))
                find2-text)))
            ))
        (if find-min?
            (begin
            (set! findtitle (string-append findtitle text-minimum (gnc:monetary->string
                                    (gnc:make-gnc-monetary report-currency
                                    (gnc:make-gnc-numeric (inexact->exact (* 100 find-min)) 100)  ))))
            (set! find-min (* 100 find-min))
            ))
        (if find-max?
            (begin
            (set! findtitle (string-append findtitle text-maximum (gnc:monetary->string
                                    (gnc:make-gnc-monetary report-currency
                                    (gnc:make-gnc-numeric (inexact->exact (* 100 find-max)) 100)  ))))
            (set! find-max (* 100 find-max))
            ))
        )))

    (set! pointer-hash (make-hash-table))
    (set! amounts-array (make-array (gnc:html-make-empty-cell) 3000 415))
    (set! guid-array (make-array #f 3000 415))
    (set! row-number 2) ; row 0 heading         row 1 number of days in the period
    (set! last-column 1)
    (set! period-number 1)
    (set! currency-type-hash (make-hash-table))
    (set! currency-lookup-hash (make-hash-table))
    (set! currency-type-num 1)
    (set! currency-type-str (number->string currency-type-num))

; The following few lines are main section where query for data and store in array

     ;get transactions for the specified period

     (get-periods-results begindate enddate); get base periods transactions - results stored in list_of_trans and 2 arrays
        (set! amounts-array (make-array (gnc-numeric-zero) (+ (length list_of_trans) 2000) (+ (length list-of-periods) 20)))
        (set! guid-array (make-array #f (+ (length list_of_trans) 2000) (+ (length list-of-periods) 20)))
     (array-set! amounts-array ;store time period title
            (if compare?
        (display-date-interval-columns begindate enddate)
        "")
            0 last-column)
     (array-set! amounts-array (caddr (car list-base-period)) 1 last-column)    ; store number of days
     (let (
        (scaling-mul-val
            (if compare-scale-automatically?
                compare-scale-to-val
                (if (eq? scale-op-val '* )
                    scale-num-val
                    1)))
        (scaling-div-val (if compare-scale-automatically?
            (caddr (car list-base-period))
            (if (eq? scale-op-val '/ )
                    scale-num-val
                    1)))
        )
     (if base?
        (store-period-values last-column list_of_trans scaling-mul-val scaling-div-val)
        (set! last-column 0))
     )
     ;; for calculating average
            (if show-average?
            (let* (
                (date-start begindate2 );(gnc:decrement-date (car dates) 0))
                (date-end enddate2)
                (num-periods (length list-of-periods))
                (avg-num-days (round (/ (caddr (car (gnc:getdatedelta (list begindate2 enddate2 'none)))) num-periods)))

                (scaling-mul-val
                    (if compare-scale-automatically?
                        compare-scale-to-val
                            (if (eq? scale-op-val2 '* )
                                scale-num-val2
                                1)))
                (scaling-div-val (if compare-scale-automatically?
                    (* avg-num-days num-periods)
                    (if (eq? scale-op-val2 '/ )
                        (* scale-num-val2 num-periods)
                       num-periods))) ;; need to divide to get average
                )

                (set! last-column (+ last-column 1))
                (array-set! amounts-array
                    (sprintf #f (_ "Average for %s %s ending %s") ;store time period title
                            (number->string (length list-of-periods))
                            deltas-val
                           (gnc-print-date date-end))
                        0 last-column)
                (get-periods-results  date-start date-end)
                (array-set! amounts-array avg-num-days 1 last-column) ;store number of days
                (store-period-values last-column list_of_trans scaling-mul-val scaling-div-val)

             ;;   calculate delta
             (let (
                ;; pointer-hash contains all of the transactions and what row in the array they are stored in
                ;; convert to list named list-thekeys
                (list-thekeys (hash-map->list cons pointer-hash)))
                (calculate-delta list-thekeys)
                (array-set! amounts-array "Delta" 0 3)
                (set! last-column 4)
                (array-set! amounts-array "" 0 4)
             )
            ))

     ;;
;; compare period is divided up into smaller parts based on users selection
;;  for loop reads in and stores as column in array each small period
    (if  compare?
        (for-each
            (lambda (dates)
            (let (
                (date-start (car dates) );(gnc:decrement-date (car dates) 0))
                (date-end (cadr dates))
                (scaling-mul-val
                    (if compare-scale-automatically?
                        compare-scale-to-val
                            (if (eq? scale-op-val2 '* )
                                scale-num-val2
                                1)))
                (scaling-div-val (if compare-scale-automatically?
                    (caddr dates)
                    (if (eq? scale-op-val2 '/ )
                        scale-num-val2
                        1)))
                )

                (set! last-column (+ last-column 1))
                (array-set! amounts-array
                    (display-date-interval-columns date-start date-end) ;store time period title
                        0 last-column)
                (get-periods-results  date-start date-end)
                (array-set! amounts-array (caddr dates) 1 last-column) ;store number of days
                (store-period-values last-column list_of_trans scaling-mul-val scaling-div-val)
            ))
     list-of-periods)
     )

(if (not (= row-number 2)) ;if row number is greater than 2 then some entries were found
 (let (
    ;; pointer-hash contains all of the transactions and what row in the array they are stored in
    ;; convert to list named list-thekeys
     (list-thekeys (hash-map->list cons pointer-hash)))

     ; if only two periods, calculate delta
     (if (= last-column 2)
        (begin
            (calculate-delta list-thekeys)
            (set! last-column 3)
            (array-set! amounts-array "Delta" 0 3)
        )
     )

     (let* (

        ; sort based on primary and secondary keys
        (sort-type (get-sort-type primary-key secondary-key))
        (var-p (comp-sort-helper sort-type 0))
        (comp-p1 (comp-sort-helper sort-type 1))
        (comp-p2 (if (equal? primary-order 'ascend)
                        (comp-sort-helper sort-type 2)
                        (comp-sort-helper sort-type 3)
                        ))
        (var-s (comp-sort-helper sort-type 4))
        (comp-s1 (comp-sort-helper sort-type 5))
        (comp-s2 (if (equal? secondary-order 'ascend)
                    (comp-sort-helper sort-type 6)
                        (comp-sort-helper sort-type 7)
                        ))
             )
        (set! list_of_trans  list_of_trans)
     (set! list-thekeys (sortkeys list-thekeys var-p var-s comp-p1 comp-p2 comp-s1 comp-s2))
        )





        (if  (> (length list-thekeys) 0)
        (begin

              (let ((table
                     (make-split-table-comp
                      list-thekeys
                      options
                      primary-comp-key secondary-comp-key
                      (comp-get-subtotal-pred optname-prime-sortkey
                                         optname-prime-subtotal
                                         optname-prime-date-subtotal)
                      (comp-get-subtotal-pred optname-sec-sortkey
                                         optname-sec-subtotal
                                         optname-sec-date-subtotal)
                      (comp-get-subheading-renderer optname-prime-sortkey
                                               optname-prime-subtotal
                                               optname-prime-date-subtotal)
                      (comp-get-subheading-renderer optname-sec-sortkey
                                               optname-sec-subtotal
                                               optname-sec-date-subtotal)
                      (comp-get-subtotal-renderer   optname-prime-sortkey
                                               optname-prime-subtotal
                                               optname-prime-date-subtotal)
                      (comp-get-subtotal-renderer   optname-sec-sortkey
                                               optname-sec-subtotal
                                               optname-sec-date-subtotal))
                        )
                    )

                (gnc:html-document-set-title! document
                    (string-append consolidated-text " " report-title) )
                (gnc:html-document-add-object!
                 document
                 (gnc:make-html-text
                  (gnc:html-markup-h3
                  (if compare?
                   (display-find findtitle)
                   (display-date-interval-find begindate enddate findtitle)))))

                (if scaled? ; for scaling
                (gnc:html-document-add-object!
                 document
                 (gnc:make-html-text
                  (gnc:html-markup-h2
                   (string-append scaling-text " "  ))))
                )

;;

  ;;optional section for troubeshooting gnctimeperiod-utilities
    ;; change to (equal? 1 1) to see variables
    ;;       use (equal? 1 "a") to hide variables
    (if (equal? 1 "a") ;;
    (begin
        (set! period-val " ")
      (let* (

      (numtransact (length list-thekeys ))

       (count 0)
       )

      (while (< count numtransact )
        (begin
 ;    get string for  1st payee    (set! firstpayee (car (list-ref total-payee-get-alist 0)))
  ;   get number for  1st amount   (set! firstamount (cdr (list-ref total-payee-get-alist 0)))

        (let* (

        (well (if #t
                    "match"
                    "no_match"))

            (current-trans     (list-ref list-thekeys count ))
            (next-one (if (< count (- numtransact 1 ))
                        (list-ref list-thekeys (+ count 1))
                        current-trans))

            (thekey (car (list-ref list-thekeys count ) ))
            (namcode (get-namecode current-trans))
            (othernam (get-other-name current-trans))
            (description (get-description current-trans))
            (amount (get-array-value-num-base current-trans))
        ;    (amount (get-row-in-array current-trans))
            (amou (cdr current-trans))
            (accountguid (get-accountguid current-trans))

    ;        (tp (get-date-tp current-trans))



        ; (comp-timepair-same-year tp-a tp-b)
    ;        (wellm (if (comp-timepair-same-week (get-date-tp current-trans)  (get-date-tp next-one))
    ;                "match"
    ;                "no"))
    ;        (currencyz (gnc-default-currency))
    ;        (currency-frac (gnc-commodity-get-fraction currencyz))
            )

         (set! period-val (string-append period-val
            " "
            (number->string count)
        ;    (txn (xaccSplitGetParent split))
        ;   (splitcount (xaccTransCountSplits txn)
            "hg"
        "guid:"
            accountguid
            "date:"
    ;        (strftime "%Y%m%d" (get-date-tm current-trans))
            " "
            well
            "Prim:"
            (get-primary-key current-trans)
            "Sec:"
            (get-secondary-key current-trans)
            "row"
            (number->string amount)
            "row1"
            (number->string amou)
            "namcod"
            namcode
            " "
            othernam
            "descrip"
            description
    ;        "currency type"
    ;        (get-currency-type current-trans)
            "the_key"
             thekey
            " "
        "  "
        "num 12 "
        (if (equal? month-val2 '4)
            "four"
            "three")

        "end test"
        )))
          (set! count (+ count 1))
      ))
    )
    (gnc:html-document-add-object!
        ;; may need to change next line or not include these 4-5 lines when adding gnctimeperiod-utilities
       document
       (gnc:make-html-text

        (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The Pick  which period option is %s.")
          (gnc:html-markup-b whichperiod-val)))




    ;    (gnc:html-markup-p
   ;      (gnc:html-markup/format
   ;       (_ "Number of items in the list is %s.")
   ;       (gnc:html-markup-b (number->string   (comp-sort-helper 'primary_secondary 8)) )))


        (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The custom date pick is %s .")
          (gnc:html-markup-b (if (equal? whichperiod-val 'customdates ) (_ "true") (_ "false")))))

        (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The year selection is %s.")
          (gnc:html-markup-b year-val)))

        (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The Pick period option is %s.")
          (gnc:html-markup-b period-val)))

        (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The Pick last option is %s.")
          (gnc:html-markup-b last-val)))

          (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The month period option is %s.")
          (gnc:html-markup-b month-val)))

     ;; Here we print the value of the number option formatted as
        ;; currency. When printing currency values, you should use
        ;; the function (xaccPrintAmount), which is defined in
        ;; report-utilities. This functions will format the number
        ;; appropriately in the current locale. Don't try to format
        ;; it yourself -- it will be wrong in other locales.
        (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The number option formatted as currency is %s.")
          (gnc:html-markup-b
           (xaccPrintAmount
            (gnc:make-gnc-numeric (inexact->exact (* 100 scale-num-val)) 100)
            (gnc-default-print-info #f)))))

          (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The find-text option is %s.")
          (gnc:html-markup-b (if find-text? (_ "true") (_ "false")))))

          (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The find-min option is %s.")
          (gnc:html-markup-b (if find-min? (_ "true") (_ "false")))))

        (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "The find-max option is %s.")
          (gnc:html-markup-b (if find-max? (_ "true") (_ "false")))))

    ;      (gnc:html-markup-p
    ;     (gnc:html-markup/format
    ;      (_ "The number option is %s.")
    ;      (gnc:html-markup-b (number->string scale-num-val))))

    ;    (gnc:html-markup-p
    ;     (gnc:html-markup/format
    ;      (_ "The period start is %s.")
    ;        (gnc:html-markup-b (number->string (car start-date-tp)))))

    ;    (gnc:html-markup-p
    ;     (gnc:html-markup/format
    ;      (_ "The period start is %s.")
    ;      (gnc:html-markup-b (gnc-print-date start-date-tp))))

    ;    (gnc:html-markup-p
    ;     (gnc:html-markup/format
    ;      (_ "The period end is %s.")
    ;      (gnc:html-markup-b (gnc-print-date end-date-tp))))

     )
    )
     ))

    ;end of optional section for gnctimeperiod-utilities

                (gnc:html-document-add-object!
                 document
                 table
                )


;; show any imbalances if option choosen
    (if (and (opt-val pagename-display optname-show-imbalance)
            ;(or (equal? primary-key 'account-name) (equal? primary-key 'account-code)
            ;    (equal? primary-key 'amount)  (equal? primary-key 'description))
            (not do-find?))
    (begin
      (let* (
       (count 0)
       (imbalance-val "")
       (accounts-imbalance (gnc:accounts-imbalance-or-orphan begindate enddate))
        (numtransact (length accounts-imbalance ))
       )
       (gnc:html-document-add-object!
        document
       (gnc:make-html-text
       (gnc:html-markup-p
         (gnc:html-markup/format
          text-dash   ; Few will realize it but report will show dash  if imbalance was checked for
          ))))

      (while (< count numtransact )
        (begin
        (let* (
            (current-account (list-ref accounts-imbalance count ))
            )
         (set! imbalance-val (string-append
              text-note-account
            (gnc-account-get-full-name current-account)
              text-changed-in-value
            (gnc:monetary->string (gnc:make-gnc-monetary (xaccAccountGetCommodity current-account)
                (gnc:account-get-balance-interval current-account begindate enddate #f)))
        ))
          (set! count (+ count 1))
      )
        (gnc:html-document-add-object!
        document
        (gnc:make-html-text
        (gnc:html-markup-p
         (gnc:html-markup/format
          (_ "  %s")
          (gnc:html-markup-b imbalance-val)))
        ))
      ))
    )))
;end for showing imbalance


                ))))
              ;; error condition: no splits found
;(if  (not (or (null? c_account_1) (and-map not c_account_1)))
 ;       (begin
              (let ((p (gnc:make-html-text)))
                (gnc:html-text-append!
                 p
                 (gnc:html-markup-h2
                  (_ "No matching transactions found"))
                 (gnc:html-markup-p
                  (_ "No transactions were found that \
match the time interval and account selection specified, \
and find requirements \
in the Options panel.")))
                (gnc:html-document-add-object! document p))
;    ))
)))


        ;; error condition: no accounts specified

        (gnc:html-document-add-object!
         document
     (gnc:html-make-no-account-warning
      report-title (gnc:report-id report-obj))
      ))
    (gnc:report-finished)
    document)
    )

;; Define the report.
(gnc:define-report

 'version 1

 'name reportname
 'report-guid "4ce3b9833af044abb929a8dbda59620f"

 'options-generator trep-options-generator

 'renderer trep-renderer)
