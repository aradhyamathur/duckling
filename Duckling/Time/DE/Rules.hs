-- Copyright (c) 2016-present, Facebook, Inc.
-- All rights reserved.
--
-- This source code is licensed under the BSD-style license found in the
-- LICENSE file in the root directory of this source tree. An additional grant
-- of patent rights can be found in the PATENTS file in the same directory.


{-# LANGUAGE GADTs #-}
{-# LANGUAGE NoRebindableSyntax #-}
{-# LANGUAGE OverloadedStrings #-}

module Duckling.Time.DE.Rules
  ( rules ) where

import Control.Monad (liftM2)
import Prelude
import Data.Text (Text)
import qualified Data.Text as Text

import Duckling.Dimensions.Types
import Duckling.Numeral.Helpers (parseInt)
import Duckling.Ordinal.Types (OrdinalData (..))
import Duckling.Regex.Types
import Duckling.Time.Helpers
import Duckling.Time.Types (TimeData (..))
import Duckling.Types
import qualified Duckling.Ordinal.Types as TOrdinal
import qualified Duckling.Time.Types as TTime
import qualified Duckling.TimeGrain.Types as TG

instants :: [(Text, TG.Grain, Int, String)]
instants =
 [ ( "now"             , TG.Second,  0,
       "(genau)? ?jetzt|diesen moment|in diesem moment|gerade eben" )
 , ( "today"           , TG.Day   ,  0,
       "heute|(um diese zeit|zu dieser zeit|um diesen zeitpunkt|zu diesem zeitpunkt)" )
 , ( "tomorrow"        , TG.Day   ,  1, "morgen" )
 , ( "yesterday"       , TG.Day   , -1, "gestern" )
 , ( "after tomorrow"  , TG.Day   ,  2, "(\x00fc)bermorgen" )
 , ( "before yesterday", TG.Day   , -2, "vorgestern" )
 , ( "EOM|End of month", TG.Month ,  1, "(das )?ende des monats?" )
 , ( "EOY|End of year" , TG.Year  ,  1,
       "(das )?(EOY|jahr(es)? ?ende|ende (des )?jahr(es)?)" )
 ]

ruleInstants :: [Rule]
ruleInstants = map go instants
  where
    go (name, grain, n, regexPattern) = Rule
      { name = name
      , pattern = [regex regexPattern]
      , prod = \_ -> tt $ cycleNth grain n
      }

daysOfWeek :: [(Text, String)]
daysOfWeek =
  [ ( "Montag"    , "montags?|mo\\.?"              )
  , ( "Dienstag"  , "die?nstags?|di\\.?"           )
  , ( "Mittwoch"  , "mittwochs?|mi\\.?"            )
  , ( "Donnerstag", "donn?erstag|do\\.?"           )
  , ( "Freitag"   , "freitags?|fr\\.?"             )
  , ( "Samstag"   , "samstags?|sonnabends?|sa\\.?" )
  , ( "Sonntag"   , "sonntags?|so\\.?"             )
  ]

ruleDaysOfWeek :: [Rule]
ruleDaysOfWeek = zipWith go daysOfWeek [1..7]
  where
    go (name, regexPattern) i = Rule
      { name = name
      , pattern = [regex regexPattern]
      , prod = \_ -> tt $ dayOfWeek i
      }

months :: [(Text, String)]
months =
  [ ( "Januar"   , "januar|jan\\.?"             )
  , ( "Februar"  , "februar|feb\\.?"            )
  , ( "Marz"     , "m(\x00e4)rz|m(\x00e4)r\\.?" )
  , ( "April"    , "april|apr\\.?"              )
  , ( "Mai"      , "mai\\.?"                    )
  , ( "Juni"     , "juni|jun\\.?"               )
  , ( "Juli"     , "juli|jul\\.?"               )
  , ( "August"   , "august|aug\\.?"             )
  , ( "September", "september|sept?\\.?"        )
  , ( "Oktober"  , "oktober|okt\\.?"            )
  , ( "November" , "november|nov\\.?"           )
  , ( "Dezember" , "dezember|dez\\.?"           )
  ]

ruleMonths :: [Rule]
ruleMonths = zipWith go months [1..12]
  where
    go (name, regexPattern) i = Rule
      { name = name
      , pattern = [regex regexPattern]
      , prod = \_ -> tt $ month i
      }

seasons :: [(Text, String, TimeData, TimeData)]
seasons =
  [ ( "sommer"  , "sommer"                , monthDay  6 21, monthDay  9 23 )
  , ( "herbst"  , "herbst"                , monthDay  9 23, monthDay 12 21 )
  , ( "winter"  , "winter"                , monthDay 12 21, monthDay  3 20 )
  , ( "fruhling", "fr(\x00fc)h(ling|jahr)", monthDay  3 20, monthDay  6 21 )
  ]

ruleSeasons :: [Rule]
ruleSeasons = map go seasons
  where
    go (name, regexPattern, start, end) = Rule
      { name = name
      , pattern = [regex regexPattern]
      , prod = \_ -> Token Time <$> interval TTime.Open start end
      }

holidays :: [(Text, TimeData, String)]
holidays =
  [ ( "new year's day"                    , monthDay  1  1, "neujahr(s?tag)?" )
  , ( "valentine's day"                   , monthDay  2 14, "valentin'?stag" )
  , ( "Schweizer Bundesfeiertag"          , monthDay  8  1,
        "schweiz(er)? (bundes)?feiertag|bundes feiertag" )
  , ( "Tag der Deutschen Einheit"         , monthDay 10  3,
        "tag (der)? deutsc?hen? einheit" )
  , ( "Oesterreichischer Nationalfeiertag", monthDay 10 26,
        "((\x00f6)sterreichischer?)? nationalfeiertag|national feiertag" )
  , ( "halloween day"                     , monthDay 10 31, "hall?owe?en?" )
  , ( "Allerheiligen"                     , monthDay 11  1,
        "allerheiligen?|aller heiligen?" )
  , ( "Nikolaus"                          , monthDay 12  6,
        "nikolaus(tag)?|nikolaus tag|nikolo" )
  , ( "christmas eve"                     , monthDay 12 24,
        "heilig(er)? abend" )
  , ( "christmas"                         , monthDay 12 25,
        "weih?nacht(en|stag)?" )
  , ( "new year's eve"                    , monthDay 12 31,
        "silvester" )
  , ( "Mother's Day"                      , nthDOWOfMonth 2 7 5,
        "mutt?ertag|mutt?er (tag)?" )
  , ( "Father's Day"                      , nthDOWOfMonth 3 7 6,
        "vatt?er( ?tag)?" )
  ]

ruleHolidays :: [Rule]
ruleHolidays = map go holidays
  where
    go (name, date, regexPattern) = Rule
      { name = name
      , pattern = [regex regexPattern]
      , prod = \_ -> tt date
      }

ruleRelativeMinutesTotillbeforeIntegerHourofday :: Rule
ruleRelativeMinutesTotillbeforeIntegerHourofday = Rule
  { name = "relative minutes to|till|before <integer> (hour-of-day)"
  , pattern =
    [ Predicate $ isIntegerBetween 1 59
    , regex "vor"
    , Predicate isAnHourOfDay
    ]
  , prod = \tokens -> case tokens of
      (token:_:Token Time td:_) -> do
        n <- getIntValue token
        t <- minutesBefore n td
        Just $ Token Time t
      _ -> Nothing
  }

ruleQuarterTotillbeforeIntegerHourofday :: Rule
ruleQuarterTotillbeforeIntegerHourofday = Rule
  { name = "quarter to|till|before <integer> (hour-of-day)"
  , pattern =
    [regex "vie?rtel vor"
    , Predicate isAnHourOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> do
        t <- minutesBefore 15 td
        Just $ Token Time t
      _ -> Nothing
  }

ruleHalfTotillbeforeIntegerHourofday :: Rule
ruleHalfTotillbeforeIntegerHourofday = Rule
  { name = "half to|till|before <integer> (hour-of-day)"
  , pattern =
    [ regex "halbe? vor"
    , Predicate isAnHourOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> do
        t <- minutesBefore 30 td
        Just $ Token Time t
      _ -> Nothing
  }

ruleTheOrdinalCycleOfTime :: Rule
ruleTheOrdinalCycleOfTime = Rule
  { name = "the <ordinal> <cycle> of <time>"
  , pattern =
    [ regex "der|die|das"
    , dimension Ordinal
    , dimension TimeGrain
    , regex "im|in|von"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Ordinal od:Token TimeGrain grain:_:Token Time td:_) ->
        tt $ cycleNthAfter True grain (TOrdinal.value od - 1) td
      _ -> Nothing
  }

ruleNthTimeOfTime2 :: Rule
ruleNthTimeOfTime2 = Rule
  { name = "nth <time> of <time>"
  , pattern =
    [ regex "der|die|das"
    , dimension Ordinal
    , dimension Time
    , regex "im"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:
       Token Ordinal (OrdinalData {TOrdinal.value = v}):
       Token Time td1:
       _:
       Token Time td2:
       _) -> Token Time . predNth (v - 1) False <$> intersect td2 td1
      _ -> Nothing
  }

ruleLastTime :: Rule
ruleLastTime = Rule
  { name = "last <time>"
  , pattern =
    [ regex "letzten?|letztes"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) ->
        tt $ predNth (-1) False td
      _ -> Nothing
  }

ruleDatetimeDatetimeInterval :: Rule
ruleDatetimeDatetimeInterval = Rule
  { name = "<datetime> - <datetime> (interval)"
  , pattern =
    [ Predicate isNotLatent
    , regex "\\-|bis( zum)?|auf( den)?"
    , Predicate isNotLatent
    ]
  , prod = \tokens -> case tokens of
      (Token Time td1:_:Token Time td2:_) ->
        Token Time <$> interval TTime.Closed td1 td2
      _ -> Nothing
  }

ruleDateDateInterval :: Rule
ruleDateDateInterval = Rule
  { name = "dd.(mm.)? - dd.mm.(yy[yy]?)? (interval)"
  , pattern =
    [ regex "(?:vo[nm]\\s+)?(10|20|30|31|[012]?[1-9])\\.?((?<=\\.)(?:10|11|12|0?[1-9])(?:\\.?))?"
    , regex "\\-|/|bis( zum)?|auf( den)?"
    , regex "(10|20|30|31|[012]?[1-9])\\.(10|11|12|0?[1-9])\\.?((?<=\\.)\\d{2,4})?"
    ]
  , prod = \tokens -> case tokens of
      (Token RegexMatch (GroupMatch (d1:"":_)):
       _:
       Token RegexMatch (GroupMatch (d2:m2:"":_)):
       _) -> do
          d1 <- parseInt d1
          d2 <- parseInt d2
          m2 <- parseInt m2
          Token Time <$> interval TTime.Closed (monthDay m2 d1) (monthDay m2 d2)
      (Token RegexMatch (GroupMatch (d1:"":_)):
       _:
       Token RegexMatch (GroupMatch (d2:m2:y:_)):
       _) -> do
          d1 <- parseInt d1
          d2 <- parseInt d2
          m2 <- parseInt m2
          y <- parseInt y
          Token Time <$> interval TTime.Closed (yearMonthDay y m2 d1) (yearMonthDay y m2 d2)
      (Token RegexMatch (GroupMatch (d1:m1:_)):
       _:
       Token RegexMatch (GroupMatch (d2:m2:"":_)):
       _) -> do
          d1 <- parseInt d1
          d2 <- parseInt d2
          m1 <- parseInt m1
          m2 <- parseInt m2
          Token Time <$> interval TTime.Closed (monthDay m1 d1) (monthDay m2 d2)
      (Token RegexMatch (GroupMatch (d1:m1:_)):
       _:
       Token RegexMatch (GroupMatch (d2:m2:y:_)):
       _) -> do
          d1 <- parseInt d1
          d2 <- parseInt d2
          m1 <- parseInt m1
          m2 <- parseInt m2
          y <- parseInt y
          Token Time <$> interval TTime.Closed (yearMonthDay y m1 d1) (yearMonthDay y m2 d2)
      _ -> Nothing
  }

ruleEvening :: Rule
ruleEvening = Rule
  { name = "evening"
  , pattern =
    [ regex "abends?"
    ]
  , prod = \_ ->
      let from = hour False 18
          to = hour False 0
      in Token Time . mkLatent . partOfDay <$>
           interval TTime.Open from to
  }

ruleTheDayofmonthNonOrdinal :: Rule
ruleTheDayofmonthNonOrdinal = Rule
  { name = "the <day-of-month> (non ordinal)"
  , pattern =
    [ regex "der"
    , Predicate $ isIntegerBetween 1 31
    ]
  , prod = \tokens -> case tokens of
      (_:token:_) -> do
        v <- getIntValue token
        tt $ dayOfMonth v
      _ -> Nothing
  }

ruleInDuration :: Rule
ruleInDuration = Rule
  { name = "in <duration>"
  , pattern =
    [ regex "in"
    , dimension Duration
    ]
  , prod = \tokens -> case tokens of
      (_:Token Duration dd:_) ->
        tt $ inDuration dd
      _ -> Nothing
  }

ruleLastCycleOfTime :: Rule
ruleLastCycleOfTime = Rule
  { name = "last <cycle> of <time>"
  , pattern =
    [ regex "letzte(r|n|s)?"
    , dimension TimeGrain
    , regex "um|im"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token TimeGrain grain:_:Token Time td:_) ->
        tt $ cycleLastOf grain td
      _ -> Nothing
  }

ruleFromDatetimeDatetimeInterval :: Rule
ruleFromDatetimeDatetimeInterval = Rule
  { name = "from <datetime> - <datetime> (interval)"
  , pattern =
    [ regex "vo[nm]"
    , dimension Time
    , regex "\\-|bis( zum)?|auf( den)?"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td1:_:Token Time td2:_) ->
        Token Time <$> interval TTime.Closed td1 td2
      _ -> Nothing
  }

ruleRelativeMinutesAfterpastIntegerHourofday :: Rule
ruleRelativeMinutesAfterpastIntegerHourofday = Rule
  { name = "relative minutes after|past <integer> (hour-of-day)"
  , pattern =
    [ Predicate $ isIntegerBetween 1 59
    , regex "nach"
    , Predicate isAnHourOfDay
    ]
  , prod = \tokens -> case tokens of
      (token:
       _:
       Token Time TimeData {TTime.form = Just (TTime.TimeOfDay (Just hours) is12H)}:
       _) -> do
        n <- getIntValue token
        tt $ hourMinute is12H hours n
      _ -> Nothing
  }

ruleQuarterAfterpastIntegerHourofday :: Rule
ruleQuarterAfterpastIntegerHourofday = Rule
  { name = "quarter after|past <integer> (hour-of-day)"
  , pattern =
    [ regex "vie?rtel nach"
    , Predicate isAnHourOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:
       Token Time TimeData {TTime.form = Just (TTime.TimeOfDay (Just hours) is12H)}:
       _) -> tt $ hourMinute is12H hours 15
      _ -> Nothing
  }

ruleHalfAfterpastIntegerHourofday :: Rule
ruleHalfAfterpastIntegerHourofday = Rule
  { name = "half after|past <integer> (hour-of-day)"
  , pattern =
    [ regex "halbe? nach"
    , Predicate isAnHourOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:
       Token Time TimeData {TTime.form = Just (TTime.TimeOfDay (Just hours) is12H)}:
       _) -> tt $ hourMinute is12H hours 30
      _ -> Nothing
  }

ruleMonthDdddInterval :: Rule
ruleMonthDdddInterval = Rule
  { name = "<month> dd-dd (interval)"
  , pattern =
    [ regex "([012]?\\d|30|31)(ter|\\.)?"
    , regex "\\-|bis( zum)?|auf( den)?"
    , regex "([012]?\\d|30|31)(ter|\\.)?"
    , Predicate isAMonth
    ]
  , prod = \tokens -> case tokens of
      (Token RegexMatch (GroupMatch (m1:_)):
       _:
       Token RegexMatch (GroupMatch (m2:_)):
       Token Time td:
       _) -> do
        v1 <- parseInt m1
        v2 <- parseInt m2
        from <- intersect (dayOfMonth v1) td
        to <- intersect (dayOfMonth v2) td
        Token Time <$> interval TTime.Closed from to
      _ -> Nothing
  }

ruleTheCycleAfterTime :: Rule
ruleTheCycleAfterTime = Rule
  { name = "the <cycle> after <time>"
  , pattern =
    [ regex "der"
    , dimension TimeGrain
    , regex "nach"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token TimeGrain grain:_:Token Time td:_) ->
        tt $ cycleNthAfter False grain 1 td
      _ -> Nothing
  }

ruleTheCycleBeforeTime :: Rule
ruleTheCycleBeforeTime = Rule
  { name = "the <cycle> before <time>"
  , pattern =
    [ regex "der"
    , dimension TimeGrain
    , regex "vor"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token TimeGrain grain:_:Token Time td:_) ->
        tt $ cycleNthAfter False grain (-1) td
      _ -> Nothing
  }

ruleYearLatent2 :: Rule
ruleYearLatent2 = Rule
  { name = "year (latent)"
  , pattern =
    [ Predicate $ isIntegerBetween 2101 10000
    ]
  , prod = \tokens -> case tokens of
      (token:_) -> do
        v <- getIntValue token
        tt . mkLatent $ year v
      _ -> Nothing
  }

ruleTimeAfterNext :: Rule
ruleTimeAfterNext = Rule
  { name = "<time> after next"
  , pattern =
    [ dimension Time
    , regex "nach dem n(\x00e4)chsten"
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:_) ->
        tt $ predNth 1 True td
      _ -> Nothing
  }

ruleTheIdesOfNamedmonth :: Rule
ruleTheIdesOfNamedmonth = Rule
  { name = "the ides of <named-month>"
  , pattern =
    [ regex "die iden (des?)"
    , Predicate isAMonth
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td@TimeData {TTime.form = Just (TTime.Month m)}:_) ->
        Token Time <$>
          intersect (dayOfMonth $ if elem m [3, 5, 7, 10] then 15 else 13) td
      _ -> Nothing
  }

ruleNoon :: Rule
ruleNoon = Rule
  { name = "noon"
  , pattern =
    [ regex "mittags?|zw(\x00f6)lf (uhr)?"
    ]
  , prod = \_ -> tt $ hour False 12
  }

ruleThisnextDayofweek :: Rule
ruleThisnextDayofweek = Rule
  { name = "this|next <day-of-week>"
  , pattern =
    [ regex "diese(n|r)|kommenden|n(\x00e4)chsten"
    , Predicate isADayOfWeek
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) ->
        tt $ predNth 0 True td
      _ -> Nothing
  }

ruleBetweenTimeofdayAndTimeofdayInterval :: Rule
ruleBetweenTimeofdayAndTimeofdayInterval = Rule
  { name = "between <time-of-day> and <time-of-day> (interval)"
  , pattern =
    [ regex "zwischen"
    , Predicate isATimeOfDay
    , regex "und"
    , Predicate isATimeOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td1:_:Token Time td2:_) ->
        Token Time <$> interval TTime.Closed td1 td2
      _ -> Nothing
  }

ruleNextCycle :: Rule
ruleNextCycle = Rule
  { name = "next <cycle>"
  , pattern =
    [ regex "n(\x00e4)chste(r|n|s)?|kommende(r|n|s)?"
    , dimension TimeGrain
    ]
  , prod = \tokens -> case tokens of
      (_:Token TimeGrain grain:_) ->
        tt $ cycleNth grain 1
      _ -> Nothing
  }

ruleTimeofdayApproximately :: Rule
ruleTimeofdayApproximately = Rule
  { name = "<time-of-day> approximately"
  , pattern =
    [ Predicate isATimeOfDay
    , regex "(um )?zirka|ungef(\x00e4)hr|etwa"
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:_) -> tt $ notLatent td
      _ -> Nothing
  }

ruleOnDate :: Rule
ruleOnDate = Rule
  { name = "on <date>"
  , pattern =
    [ regex "am"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:x:_) -> Just x
      _ -> Nothing
  }

ruleDurationFromNow :: Rule
ruleDurationFromNow = Rule
  { name = "<duration> from now"
  , pattern =
    [ dimension Duration
    , regex "ab (heute|jetzt)"
    ]
  , prod = \tokens -> case tokens of
      (Token Duration dd:_) ->
        tt $ inDuration dd
      _ -> Nothing
  }

ruleLunch :: Rule
ruleLunch = Rule
  { name = "lunch"
  , pattern =
    [ regex "(am |zu )?mittags?"
    ]
  , prod = \_ ->
      let from = hour False 12
          to = hour False 14
      in Token Time . mkLatent . partOfDay <$>
           interval TTime.Open from to
  }

ruleLastCycle :: Rule
ruleLastCycle = Rule
  { name = "last <cycle>"
  , pattern =
    [ regex "letzte(r|n|s)?|vergangene(r|n|s)?"
    , dimension TimeGrain
    ]
  , prod = \tokens -> case tokens of
      (_:Token TimeGrain grain:_) ->
        tt . cycleNth grain $ - 1
      _ -> Nothing
  }

ruleAfternoon :: Rule
ruleAfternoon = Rule
  { name = "afternoon"
  , pattern =
    [ regex "nach ?mittags?"
    ]
  , prod = \_ ->
      let from = hour False 12
          to = hour False 19
      in Token Time . mkLatent . partOfDay <$>
           interval TTime.Open from to
  }

ruleTimeBeforeLast :: Rule
ruleTimeBeforeLast = Rule
  { name = "<time> before last"
  , pattern =
    [ regex "vorletzten?|vor ?letztes?"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) ->
        tt $ predNth (-2) False td
      _ -> Nothing
  }

ruleNamedmonthDayofmonthOrdinal :: Rule
ruleNamedmonthDayofmonthOrdinal = Rule
  { name = "<named-month> <day-of-month> (ordinal)"
  , pattern =
    [ Predicate isAMonth
    , Predicate isDOMOrdinal
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:token:_) -> Token Time <$> intersectDOM td token
      _ -> Nothing
  }

ruleInduringThePartofday :: Rule
ruleInduringThePartofday = Rule
  { name = "in|during the <part-of-day>"
  , pattern =
    [ regex "(in|an|am|w(\x00e4)h?rend)( der| dem| des)?"
    , Predicate isAPartOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) ->
        tt $ notLatent td
      _ -> Nothing
  }

ruleHourofdayIntegerAsRelativeMinutes :: Rule
ruleHourofdayIntegerAsRelativeMinutes = Rule
  { name = "<hour-of-day> <integer> (as relative minutes)"
  , pattern =
    [ Predicate isAnHourOfDay
    , Predicate $ isIntegerBetween 1 59
    ]
  , prod = \tokens -> case tokens of
      (Token Time TimeData {TTime.form = Just (TTime.TimeOfDay (Just hours) is12H)}:
       token:
       _) -> do
        n <- getIntValue token
        tt $ hourMinute is12H hours n
      _ -> Nothing
  }

ruleHourofdayQuarter :: Rule
ruleHourofdayQuarter = Rule
  { name = "<hour-of-day> <quarter> (as relative minutes)"
  , pattern =
    [ Predicate isAnHourOfDay
    , regex "vie?rtel"
    ]
  , prod = \tokens -> case tokens of
      (Token Time TimeData {TTime.form = Just (TTime.TimeOfDay (Just hours) is12H)}:_) ->
        tt $ hourMinute is12H hours 15
      _ -> Nothing
  }

ruleHourofdayHalf :: Rule
ruleHourofdayHalf = Rule
  { name = "<hour-of-day> <half> (as relative minutes)"
  , pattern =
    [ Predicate isAnHourOfDay
    , regex "halbe?"
    ]
  , prod = \tokens -> case tokens of
      (Token Time TimeData {TTime.form = Just (TTime.TimeOfDay (Just hours) is12H)}:_) ->
        tt $ hourMinute is12H hours 30
      _ -> Nothing
  }

ruleDayofmonthordinalNamedmonth :: Rule
ruleDayofmonthordinalNamedmonth = Rule
  { name = "<day-of-month>(ordinal) <named-month>"
  , pattern =
    [ Predicate isDOMOrdinal
    , Predicate isAMonth
    ]
  , prod = \tokens -> case tokens of
      (token:Token Time td:_) -> Token Time <$> intersectDOM td token
      _ -> Nothing
  }

ruleIntersectBy :: Rule
ruleIntersectBy = Rule
  { name = "intersect by ','"
  , pattern =
    [ Predicate isNotLatent
    , regex ",( den|r)?"
    , Predicate isNotLatent
    ]
  , prod = \tokens -> case tokens of
      (Token Time td1:_:Token Time td2:_) ->
        Token Time <$> intersect td1 td2
      _ -> Nothing
  }

ruleNthTimeAfterTime :: Rule
ruleNthTimeAfterTime = Rule
  { name = "nth <time> after <time>"
  , pattern =
    [ dimension Ordinal
    , dimension Time
    , regex "nach"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (Token Ordinal (OrdinalData {TOrdinal.value = v}):
       Token Time td1:
       _:
       Token Time td2:
       _) -> tt $ predNthAfter (v - 1) td1 td2
      _ -> Nothing
  }

ruleMmdd :: Rule
ruleMmdd = Rule
  { name = "mm/dd"
  , pattern =
    [ regex "(?:am\\s+)?([012]?[1-9]|10|20|30|31)\\.(10|11|12|0?[1-9])\\.?"
    ]
  , prod = \tokens -> case tokens of
      (Token RegexMatch (GroupMatch (m1:m2:_)):_) -> do
        d <- parseInt m1
        m <- parseInt m2
        tt $ monthDay m d
      _ -> Nothing
  }

ruleAfterDuration :: Rule
ruleAfterDuration = Rule
  { name = "after <duration>"
  , pattern =
    [ regex "nach"
    , dimension Duration
    ]
  , prod = \tokens -> case tokens of
      (_:Token Duration dd:_) ->
        tt $ inDuration dd
      _ -> Nothing
  }

ruleTimeofdayLatent :: Rule
ruleTimeofdayLatent = Rule
  { name = "time-of-day (latent)"
  , pattern =
    [ Predicate $ isIntegerBetween 0 23
    ]
  , prod = \tokens -> case tokens of
      (token:_) -> do
        n <- getIntValue token
        tt . mkLatent $ hour (n < 12) n
      _ -> Nothing
  }

ruleFromTimeofdayTimeofdayInterval :: Rule
ruleFromTimeofdayTimeofdayInterval = Rule
  { name = "from <time-of-day> - <time-of-day> (interval)"
  , pattern =
    [ regex "(von|nach|ab|fr(\x00fc)hestens (um)?)"
    , Predicate isATimeOfDay
    , regex "((noch|aber|jedoch)? vor)|\\-|bis"
    , Predicate isATimeOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td1:_:Token Time td2:_) ->
        Token Time <$> interval TTime.Closed td1 td2
      _ -> Nothing
  }

ruleExactlyTimeofday :: Rule
ruleExactlyTimeofday = Rule
  { name = "exactly <time-of-day>"
  , pattern =
    [ regex "genau|exakt|p(\x00fc)nktlich|punkt( um)?"
    , Predicate isATimeOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> tt $ notLatent td
      _ -> Nothing
  }

ruleBetweenDatetimeAndDatetimeInterval :: Rule
ruleBetweenDatetimeAndDatetimeInterval = Rule
  { name = "between <datetime> and <datetime> (interval)"
  , pattern =
    [ regex "zwischen"
    , dimension Time
    , regex "und"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td1:_:Token Time td2:_) ->
        Token Time <$> interval TTime.Closed td1 td2
      _ -> Nothing
  }

ruleDurationAgo :: Rule
ruleDurationAgo = Rule
  { name = "<duration> ago"
  , pattern =
    [ regex "vor"
    , dimension Duration
    ]
  , prod = \tokens -> case tokens of
      (_:Token Duration dd:_) ->
        tt $ durationAgo dd
      _ -> Nothing
  }

ruleByTheEndOfTime :: Rule
ruleByTheEndOfTime = Rule
  { name = "by the end of <time>"
  , pattern =
    [ regex "bis (zum)? ende (von)?|(noch)? vor"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> Token Time <$>
        interval TTime.Closed td (cycleNth TG.Second 0)
      _ -> Nothing
  }

ruleAfterWork :: Rule
ruleAfterWork = Rule
  { name = "after work"
  , pattern =
    [ regex "nach (der)? arbeit|(am)? feier ?abend"
    ]
  , prod = \_ -> do
      let td1 = cycleNth TG.Day 0
      td2 <- interval TTime.Open (hour False 17) (hour False 21)
      Token Time . partOfDay <$> intersect td1 td2
  }

ruleLastNCycle :: Rule
ruleLastNCycle = Rule
  { name = "last n <cycle>"
  , pattern =
    [ regex "letzten?|vergangenen?"
    , Predicate $ isIntegerBetween 1 9999
    , dimension TimeGrain
    ]
  , prod = \tokens -> case tokens of
      (_:token:Token TimeGrain grain:_) -> do
        n <- getIntValue token
        tt $ cycleN True grain (- n)
      _ -> Nothing
  }

ruleTimeofdaySharp :: Rule
ruleTimeofdaySharp = Rule
  { name = "<time-of-day> sharp"
  , pattern =
    [ Predicate isATimeOfDay
    , regex "genau|exakt|p(\x00fc)nktlich|punkt( um)?"
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:_) -> tt $ notLatent td
      _ -> Nothing
  }

ruleWithinDuration :: Rule
ruleWithinDuration = Rule
  { name = "within <duration>"
  , pattern =
    [ regex "binnen|innerhalb( von)?"
    , dimension Duration
    ]
  , prod = \tokens -> case tokens of
      (_:Token Duration dd:_) -> Token Time <$>
        interval TTime.Open (cycleNth TG.Second 0) (inDuration dd)
      _ -> Nothing
  }

ruleMidnighteodendOfDay :: Rule
ruleMidnighteodendOfDay = Rule
  { name = "midnight|EOD|end of day"
  , pattern =
    [ regex "mitternacht|EOD|tagesende|ende (des)? tag(es)?"
    ]
  , prod = \_ -> tt $ hour False 0
  }

ruleDayofmonthNonOrdinalNamedmonth :: Rule
ruleDayofmonthNonOrdinalNamedmonth = Rule
  { name = "<day-of-month> (non ordinal) <named-month>"
  , pattern =
    [ Predicate isDOMInteger
    , Predicate isAMonth
    ]
  , prod = \tokens -> case tokens of
      (token:Token Time td:_) -> Token Time <$> intersectDOM td token
      _ -> Nothing
  }

ruleIntersect :: Rule
ruleIntersect = Rule
  { name = "intersect"
  , pattern =
    [ Predicate isNotLatent
    , Predicate isNotLatent
    ]
  , prod = \tokens -> case tokens of
      (Token Time td1:Token Time td2:_) ->
        Token Time <$> intersect td1 td2
      _ -> Nothing
  }

ruleAboutTimeofday :: Rule
ruleAboutTimeofday = Rule
  { name = "about <time-of-day>"
  , pattern =
    [ regex "(um )?zirka|ca\\.?|ungef(\x00e4)hr|etwa|gegen"
    , Predicate isATimeOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> tt $ notLatent td
      _ -> Nothing
  }

ruleUntilTimeofday :: Rule
ruleUntilTimeofday = Rule
  { name = "until <time-of-day>"
  , pattern =
    [ regex "vor|bis( zu[rm]?)?|sp(\x00e4)testens?"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> tt $ withDirection TTime.Before td
      _ -> Nothing
  }

ruleUntilTimeofdayPostfix :: Rule
ruleUntilTimeofdayPostfix = Rule
  { name = "<time-of-day> until"
  , pattern =
    [ dimension Time
    , regex "sp(\x00e4)testens"
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:_:_) -> tt $ withDirection TTime.Before td
      _ -> Nothing
  }

ruleAtTimeofday :: Rule
ruleAtTimeofday = Rule
  { name = "at <time-of-day>"
  , pattern =
    [ regex "um|@"
    , Predicate isATimeOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> tt $ notLatent td
      _ -> Nothing
  }

ruleNthTimeOfTime :: Rule
ruleNthTimeOfTime = Rule
  { name = "nth <time> of <time>"
  , pattern =
    [ dimension Ordinal
    , dimension Time
    , regex "im"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (Token Ordinal (OrdinalData {TOrdinal.value = v}):
       Token Time td1:
       _:
       Token Time td2:
       _) -> Token Time . predNth (v - 1) False <$> intersect td2 td1
      _ -> Nothing
  }

ruleTimePartofday :: Rule
ruleTimePartofday = Rule
  { name = "<time> <part-of-day>"
  , pattern =
    [ dimension Time
    , Predicate isAPartOfDay
    ]
  , prod = \tokens -> case tokens of
      (Token Time td1:Token Time td2:_) ->
        Token Time <$> intersect td1 td2
      _ -> Nothing
  }

ruleWeekend :: Rule
ruleWeekend = Rule
  { name = "week-end"
  , pattern =
    [ regex "wochen ?ende?"
    ]
  , prod = \_ -> tt weekend
  }

ruleNthTimeAfterTime2 :: Rule
ruleNthTimeAfterTime2 = Rule
  { name = "nth <time> after <time>"
  , pattern =
    [ regex "der|das"
    , dimension Ordinal
    , dimension Time
    , regex "nach"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:
       Token Ordinal (OrdinalData {TOrdinal.value = v}):
       Token Time td1:
       _:
       Token Time td2:
       _) -> tt $ predNthAfter (v - 1) td1 td2
      _ -> Nothing
  }

ruleNextTime :: Rule
ruleNextTime = Rule
  { name = "next <time>"
  , pattern =
    [ regex "(n(\x00e4)chste|kommende)[ns]?"
    , Predicate isNotLatent
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) ->
        tt $ predNth 0 True td
      _ -> Nothing
  }

ruleOrdinalQuarterYear :: Rule
ruleOrdinalQuarterYear = Rule
  { name = "<ordinal> quarter <year>"
  , pattern =
    [ dimension Ordinal
    , Predicate $ isGrain TG.Quarter
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (Token Ordinal od:_:Token Time td:_) ->
        tt $ cycleNthAfter False TG.Quarter (TOrdinal.value od - 1) td
      _ -> Nothing
  }

ruleYyyymmdd :: Rule
ruleYyyymmdd = Rule
  { name = "yyyy-mm-dd"
  , pattern =
    [ regex "(\\d{2,4})-(0?[1-9]|10|11|12)-([012]?[1-9]|10|20|30|31)"
    ]
  , prod = \tokens -> case tokens of
      (Token RegexMatch (GroupMatch (m1:m2:m3:_)):_) -> do
        y <- parseInt m1
        m <- parseInt m2
        d <- parseInt m3
        tt $ yearMonthDay y m d
      _ -> Nothing
  }

ruleTheOrdinalCycleAfterTime :: Rule
ruleTheOrdinalCycleAfterTime = Rule
  { name = "the <ordinal> <cycle> after <time>"
  , pattern =
    [ regex "the"
    , dimension Ordinal
    , dimension TimeGrain
    , regex "nach"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Ordinal od:Token TimeGrain grain:_:Token Time td:_) ->
        tt $ cycleNthAfter True grain (TOrdinal.value od - 1) td
      _ -> Nothing
  }

ruleIntersectByOfFromS :: Rule
ruleIntersectByOfFromS = Rule
  { name = "intersect by 'of', 'from', 's"
  , pattern =
    [ Predicate isNotLatent
    , regex "von|der|im"
    , Predicate isNotLatent
    ]
  , prod = \tokens -> case tokens of
      (Token Time td1:_:Token Time td2:_) ->
        Token Time <$> intersect td1 td2
      _ -> Nothing
  }

ruleNextNCycle :: Rule
ruleNextNCycle = Rule
  { name = "next n <cycle>"
  , pattern =
    [ regex "n(\x00e4)chsten?|kommenden?"
    , Predicate $ isIntegerBetween 1 9999
    , dimension TimeGrain
    ]
  , prod = \tokens -> case tokens of
      (_:token:Token TimeGrain grain:_) -> do
        v <- getIntValue token
        tt $ cycleN True grain v
      _ -> Nothing
  }

ruleADuration :: Rule
ruleADuration = Rule
  { name = "a <duration>"
  , pattern =
    [ regex "(in )?eine?(r|n)?"
    , dimension Duration
    ]
  , prod = \tokens -> case tokens of
      (_:Token Duration dd:_) ->
        tt $ inDuration dd
      _ -> Nothing
  }

ruleMorning :: Rule
ruleMorning = Rule
  { name = "morning"
  , pattern =
    [ regex "morgens|(in der )?fr(\x00fc)h|vor ?mittags?|am morgen"
    ]
  , prod = \_ ->
      let from = hour False 3
          to = hour False 12
      in Token Time . mkLatent . partOfDay <$>
           interval TTime.Open from to
  }

ruleThisPartofday :: Rule
ruleThisPartofday = Rule
  { name = "this <part-of-day>"
  , pattern =
    [ regex "diesen?|dieses|heute"
    , Predicate isAPartOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> Token Time . partOfDay <$>
        intersect (cycleNth TG.Day 0) td
      _ -> Nothing
  }

ruleThisCycle :: Rule
ruleThisCycle = Rule
  { name = "this <cycle>"
  , pattern =
    [ regex "diese(r|n|s)?|kommende(r|n|s)?"
    , dimension TimeGrain
    ]
  , prod = \tokens -> case tokens of
      (_:Token TimeGrain grain:_) ->
        tt $ cycleNth grain 0
      _ -> Nothing
  }

ruleThisTime :: Rule
ruleThisTime = Rule
  { name = "this <time>"
  , pattern =
    [ regex "diese(n|r|s)?|(im )?laufenden"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) ->
        tt $ predNth 0 False td
      _ -> Nothing
  }

ruleDurationHence :: Rule
ruleDurationHence = Rule
  { name = "<duration> hence"
  , pattern =
    [ dimension Duration
    , regex "hence"
    ]
  , prod = \tokens -> case tokens of
      (Token Duration dd:_) ->
        tt $ inDuration dd
      _ -> Nothing
  }

ruleDayofmonthNonOrdinalOfNamedmonth :: Rule
ruleDayofmonthNonOrdinalOfNamedmonth = Rule
  { name = "<day-of-month> (non ordinal) of <named-month>"
  , pattern =
    [ Predicate isDOMInteger
    , regex "vom|von"
    , Predicate isAMonth
    ]
  , prod = \tokens -> case tokens of
      (token:_:Token Time td:_) -> Token Time <$> intersectDOM td token
      _ -> Nothing
  }

ruleAfterLunch :: Rule
ruleAfterLunch = Rule
  { name = "after lunch"
  , pattern =
    [ regex "nach dem mittagessen|nachmittags?"
    ]
  , prod = \_ -> do
      let td1 = cycleNth TG.Day 0
      td2 <- interval TTime.Open (hour False 13) (hour False 17)
      Token Time . partOfDay <$> intersect td1 td2
  }

ruleOnANamedday :: Rule
ruleOnANamedday = Rule
  { name = "on a named-day"
  , pattern =
    [ regex "an einem"
    , Predicate isADayOfWeek
    ]
  , prod = \tokens -> case tokens of
      (_:x:_) -> Just x
      _ -> Nothing
  }

ruleYearLatent :: Rule
ruleYearLatent = Rule
  { name = "year (latent)"
  , pattern =
    [ Predicate $
        liftM2 (||) (isIntegerBetween (- 10000) 0) (isIntegerBetween 25 999)
    ]
  , prod = \tokens -> case tokens of
      (token:_) -> do
        y <- getIntValue token
        tt . mkLatent $ year y
      _ -> Nothing
  }

ruleAfterTimeofday :: Rule
ruleAfterTimeofday = Rule
  { name = "after <time-of-day>"
  , pattern =
    [ regex "nach|ab|fr(\x00fc)he?stens"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> tt $ withDirection TTime.After td
      _ -> Nothing
  }

ruleAfterTimeofdayPostfix :: Rule
ruleAfterTimeofdayPostfix = Rule
  { name = "<time-of-day> after"
  , pattern =
    [ dimension Time
    , regex "fr(\x00fc)he?stens"
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:_:_) -> tt $ withDirection TTime.After td
      _ -> Nothing
  }

ruleNight :: Rule
ruleNight = Rule
  { name = "night"
  , pattern =
    [ regex "nachts?"
    ]
  , prod = \_ ->
      let from = hour False 0
          to = hour False 4
      in Token Time . mkLatent . partOfDay <$>
           interval TTime.Open from to
  }

ruleDayofmonthOrdinal :: Rule
ruleDayofmonthOrdinal = Rule
  { name = "<day-of-month> (ordinal)"
  , pattern =
    [ Predicate isDOMOrdinal
    ]
  , prod = \tokens -> case tokens of
      (Token Ordinal (OrdinalData {TOrdinal.value = v}):_) ->
        tt $ dayOfMonth v
      _ -> Nothing
  }

ruleTimeofdayAmpm :: Rule
ruleTimeofdayAmpm = Rule
  { name = "<time-of-day> am|pm"
  , pattern =
    [ Predicate isATimeOfDay
    , regex "([ap])\\.?m\\.?(?:[\\s'\"-_{}\\[\\]()]|$)"
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:Token RegexMatch (GroupMatch (ap:_)):_) ->
        tt . timeOfDayAMPM td $ Text.toLower ap == "a"
      _ -> Nothing
  }

ruleHalfIntegerGermanStyleHourofday :: Rule
ruleHalfIntegerGermanStyleHourofday = Rule
  { name = "half <integer> (german style hour-of-day)"
  , pattern =
    [ regex "halb"
    , Predicate isAnHourOfDay
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) -> do
        t <- minutesBefore 30 td
        Just $ Token Time t
      _ -> Nothing
  }

ruleOrdinalCycleAfterTime :: Rule
ruleOrdinalCycleAfterTime = Rule
  { name = "<ordinal> <cycle> after <time>"
  , pattern =
    [ dimension Ordinal
    , dimension TimeGrain
    , regex "nach"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (Token Ordinal od:Token TimeGrain grain:_:Token Time td:_) ->
        tt $ cycleNthAfter True grain (TOrdinal.value od - 1) td
      _ -> Nothing
  }

ruleOrdinalCycleOfTime :: Rule
ruleOrdinalCycleOfTime = Rule
  { name = "<ordinal> <cycle> of <time>"
  , pattern =
    [ dimension Ordinal
    , dimension TimeGrain
    , regex "im|in|von"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (Token Ordinal od:Token TimeGrain grain:_:Token Time td:_) ->
        tt $ cycleNthAfter True grain (TOrdinal.value od - 1) td
      _ -> Nothing
  }

ruleAfterNextTime :: Rule
ruleAfterNextTime = Rule
  { name = "after next <time>"
  , pattern =
    [ regex "(\x00fc)ber ?n(\x00e4)chste[ns]?"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td:_) ->
        tt $ predNth 1 True td
      _ -> Nothing
  }

ruleHhmm :: Rule
ruleHhmm = Rule
  { name = "hh:mm"
  , pattern =
    [ regex "((?:[01]?\\d)|(?:2[0-3]))[:.h]([0-5]\\d)(?:uhr|h)?"
    ]
  , prod = \tokens -> case tokens of
      (Token RegexMatch (GroupMatch (m1:m2:_)):_) -> do
        h <- parseInt m1
        m <- parseInt m2
        tt $ hourMinute False h m
      _ -> Nothing
  }

ruleTonight :: Rule
ruleTonight = Rule
  { name = "tonight"
  , pattern =
    [ regex "heute? (am)? abends?"
    ]
  , prod = \_ -> do
      let td1 = cycleNth TG.Day 0
      td2 <- interval TTime.Open (hour False 18) (hour False 0)
      Token Time . partOfDay <$> intersect td1 td2
  }

ruleYear :: Rule
ruleYear = Rule
  { name = "year"
  , pattern =
    [ Predicate $ isIntegerBetween 1000 2100
    ]
  , prod = \tokens -> case tokens of
      (token:_) -> do
        y <- getIntValue token
        tt $ year y
      _ -> Nothing
  }

ruleNamedmonthDayofmonthNonOrdinal :: Rule
ruleNamedmonthDayofmonthNonOrdinal = Rule
  { name = "<named-month> <day-of-month> (non ordinal)"
  , pattern =
    [ Predicate isAMonth
    , Predicate isDOMInteger
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:token:_) -> Token Time <$> intersectDOM td token
      _ -> Nothing
  }

ruleHhmmMilitary :: Rule
ruleHhmmMilitary = Rule
  { name = "hhmm (military)"
  , pattern =
    [ regex "((?:[01]?\\d)|(?:2[0-3]))([0-5]\\d)"
    ]
  , prod = \tokens -> case tokens of
      (Token RegexMatch (GroupMatch (h:m:_)):_) -> do
        hh <- parseInt h
        mm <- parseInt m
        tt . mkLatent $ hourMinute False hh mm
      _ -> Nothing
  }

ruleAbsorptionOfAfterNamedDay :: Rule
ruleAbsorptionOfAfterNamedDay = Rule
  { name = "absorption of , after named day"
  , pattern =
    [ Predicate isADayOfWeek
    , regex ","
    ]
  , prod = \tokens -> case tokens of
      (x:_) -> Just x
      _ -> Nothing
  }

ruleLastDayofweekOfTime :: Rule
ruleLastDayofweekOfTime = Rule
  { name = "last <day-of-week> of <time>"
  , pattern =
    [ regex "letzte(r|n|s)?"
    , Predicate isADayOfWeek
    , regex "[ui]m"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (_:Token Time td1:_:Token Time td2:_) ->
        tt $ predLastOf td1 td2
      _ -> Nothing
  }

ruleHhmmMilitaryAmpm :: Rule
ruleHhmmMilitaryAmpm = Rule
  { name = "hhmm (military) am|pm"
  , pattern =
    [ regex "((?:1[012]|0?\\d))([0-5]\\d)"
    , regex "([ap])\\.?m\\.?(?:[\\s'\"-_{}\\[\\]()]|$)"
    ]
  , prod = \tokens -> case tokens of
      (Token RegexMatch (GroupMatch (hh:mm:_)):Token RegexMatch (GroupMatch (ap:_)):_) -> do
        h <- parseInt hh
        m <- parseInt mm
        tt . timeOfDayAMPM (hourMinute True h m) $
          Text.toLower ap == "a"
      _ -> Nothing
  }

ruleTimeofdayTimeofdayInterval :: Rule
ruleTimeofdayTimeofdayInterval = Rule
  { name = "<time-of-day> - <time-of-day> (interval)"
  , pattern =
    [ Predicate $ liftM2 (&&) isATimeOfDay isNotLatent
    , regex "\\-|bis"
    , Predicate isATimeOfDay
    ]
  , prod = \tokens -> case tokens of
      (Token Time td1:_:Token Time td2:_) ->
        Token Time <$> interval TTime.Closed td1 td2
      _ -> Nothing
  }

ruleTimeofdayTimeofdayInterval2 :: Rule
ruleTimeofdayTimeofdayInterval2 = Rule
  { name = "<time-of-day> - <time-of-day> (interval)"
  , pattern =
    [ Predicate isATimeOfDay
    , regex "\\-|/|bis"
    , Predicate $ liftM2 (&&) isATimeOfDay isNotLatent
    ]
  , prod = \tokens -> case tokens of
      (Token Time td1:_:Token Time td2:_) ->
        Token Time <$> interval TTime.Closed td1 td2
      _ -> Nothing
  }

ruleDurationAfterTime :: Rule
ruleDurationAfterTime = Rule
  { name = "<duration> after <time>"
  , pattern =
    [ dimension Duration
    , regex "nach"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (Token Duration dd:_:Token Time td:_) ->
        tt $ durationAfter dd td
      _ -> Nothing
  }

ruleOrdinalQuarter :: Rule
ruleOrdinalQuarter = Rule
  { name = "<ordinal> quarter"
  , pattern =
    [ dimension Ordinal
    , Predicate $ isGrain TG.Quarter
    ]
  , prod = \tokens -> case tokens of
      (Token Ordinal (OrdinalData {TOrdinal.value = v}):_) -> tt .
        cycleNthAfter False TG.Quarter (v - 1) $ cycleNth TG.Year 0
      _ -> Nothing
  }

ruleTheDayofmonthOrdinal :: Rule
ruleTheDayofmonthOrdinal = Rule
  { name = "the <day-of-month> (ordinal)"
  , pattern =
    [ regex "der"
    , Predicate isDOMOrdinal
    ]
  , prod = \tokens -> case tokens of
      (_:Token Ordinal (OrdinalData {TOrdinal.value = v}):_) ->
        tt $ dayOfMonth v
      _ -> Nothing
  }

ruleDurationBeforeTime :: Rule
ruleDurationBeforeTime = Rule
  { name = "<duration> before <time>"
  , pattern =
    [ dimension Duration
    , regex "vor"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (Token Duration dd:_:Token Time td:_) ->
        tt $ durationBefore dd td
      _ -> Nothing
  }

rulePartofdayOfTime :: Rule
rulePartofdayOfTime = Rule
  { name = "<part-of-day> of <time>"
  , pattern =
    [ Predicate isAPartOfDay
    , regex "des|von|vom|am"
    , dimension Time
    ]
  , prod = \tokens -> case tokens of
      (Token Time td1:_:Token Time td2:_) ->
        Token Time <$> intersect td1 td2
      _ -> Nothing
  }

ruleMmddyyyy :: Rule
ruleMmddyyyy = Rule
  { name = "mm/dd/yyyy"
  , pattern =
    [ regex "([012]?[1-9]|10|20|30|31)\\.(0?[1-9]|10|11|12)\\.(\\d{2,4})"
    ]
  , prod = \tokens -> case tokens of
      (Token RegexMatch (GroupMatch (m1:m2:m3:_)):_) -> do
        y <- parseInt m3
        m <- parseInt m2
        d <- parseInt m1
        tt $ yearMonthDay y m d
      _ -> Nothing
  }

ruleTimeofdayOclock :: Rule
ruleTimeofdayOclock = Rule
  { name = "<time-of-day>  o'clock"
  , pattern =
    [ Predicate isATimeOfDay
    , regex "uhr|h(?:[\\s'\"-_{}\\[\\]()]|$)"
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:_) ->
        tt $ notLatent td
      _ -> Nothing
  }

ruleDayofmonthordinalNamedmonthYear :: Rule
ruleDayofmonthordinalNamedmonthYear = Rule
  { name = "<day-of-month>(ordinal) <named-month> year"
  , pattern =
    [ Predicate isDOMOrdinal
    , Predicate isAMonth
    , regex "(\\d{2,4})"
    ]
  , prod = \tokens -> case tokens of
      (token:
       Token Time td:
       Token RegexMatch (GroupMatch (match:_)):
       _) -> do
        n <- parseInt match
        dom <- intersectDOM td token
        Token Time <$> intersect dom (year n)
      _ -> Nothing
  }

ruleTimezone :: Rule
ruleTimezone = Rule
  { name = "<time> timezone"
  , pattern =
    [ Predicate $ liftM2 (&&) isATimeOfDay isNotLatent
    , regex "\\b(YEKT|YEKST|YAKT|YAKST|WITA|WIT|WIB|WGT|WGST|WFT|WET|WEST|WAT|WAST|VUT|VLAT|VLAST|VET|UZT|UYT|UYST|UTC|ULAT|TVT|TMT|TLT|TKT|TJT|TFT|TAHT|SST|SRT|SGT|SCT|SBT|SAST|SAMT|RET|PYT|PYST|PWT|PST|PONT|PMST|PMDT|PKT|PHT|PHOT|PGT|PETT|PETST|PET|PDT|OMST|OMSST|NZST|NZDT|NUT|NST|NPT|NOVT|NOVST|NFT|NDT|NCT|MYT|MVT|MUT|MST|MSK|MSD|MMT|MHT|MDT|MAWT|MART|MAGT|MAGST|LINT|LHST|LHDT|KUYT|KST|KRAT|KRAST|KGT|JST|IST|IRST|IRKT|IRKST|IRDT|IOT|IDT|ICT|HOVT|HKT|GYT|GST|GMT|GILT|GFT|GET|GAMT|GALT|FNT|FKT|FKST|FJT|FJST|EST|EGT|EGST|EET|EEST|EDT|ECT|EAT|EAST|EASST|DAVT|ChST|CXT|CVT|CST|COT|CLT|CLST|CKT|CHAST|CHADT|CET|CEST|CDT|CCT|CAT|CAST|BTT|BST|BRT|BRST|BOT|BNT|AZT|AZST|AZOT|AZOST|AWST|AWDT|AST|ART|AQTT|ANAT|ANAST|AMT|AMST|ALMT|AKST|AKDT|AFT|AEST|AEDT|ADT|ACST|ACDT)\\b"
    ]
  , prod = \tokens -> case tokens of
      (Token Time td:
       Token RegexMatch (GroupMatch (tz:_)):
       _) -> Token Time <$> inTimezone tz td
      _ -> Nothing
  }

rules :: [Rule]
rules =
  [ ruleADuration
  , ruleAboutTimeofday
  , ruleAbsorptionOfAfterNamedDay
  , ruleAfterDuration
  , ruleAfterLunch
  , ruleAfterNextTime
  , ruleAfterTimeofday
  , ruleAfterTimeofdayPostfix
  , ruleAfterWork
  , ruleAfternoon
  , ruleAtTimeofday
  , ruleBetweenDatetimeAndDatetimeInterval
  , ruleBetweenTimeofdayAndTimeofdayInterval
  , ruleByTheEndOfTime
  , ruleDatetimeDatetimeInterval
  , ruleDateDateInterval
  , ruleDayofmonthNonOrdinalNamedmonth
  , ruleDayofmonthNonOrdinalOfNamedmonth
  , ruleDayofmonthOrdinal
  , ruleDayofmonthordinalNamedmonth
  , ruleDayofmonthordinalNamedmonthYear
  , ruleDurationAfterTime
  , ruleDurationAgo
  , ruleDurationBeforeTime
  , ruleDurationFromNow
  , ruleDurationHence
  , ruleEvening
  , ruleExactlyTimeofday
  , ruleFromDatetimeDatetimeInterval
  , ruleFromTimeofdayTimeofdayInterval
  , ruleHalfIntegerGermanStyleHourofday
  , ruleHhmm
  , ruleHhmmMilitary
  , ruleHhmmMilitaryAmpm
  , ruleHourofdayIntegerAsRelativeMinutes
  , ruleInDuration
  , ruleInduringThePartofday
  , ruleIntersect
  , ruleIntersectBy
  , ruleIntersectByOfFromS
  , ruleLastCycle
  , ruleLastCycleOfTime
  , ruleLastDayofweekOfTime
  , ruleLastNCycle
  , ruleLastTime
  , ruleLunch
  , ruleMidnighteodendOfDay
  , ruleMmdd
  , ruleMmddyyyy
  , ruleMonthDdddInterval
  , ruleMorning
  , ruleNamedmonthDayofmonthNonOrdinal
  , ruleNamedmonthDayofmonthOrdinal
  , ruleNextCycle
  , ruleNextNCycle
  , ruleNextTime
  , ruleNight
  , ruleNoon
  , ruleNthTimeAfterTime
  , ruleNthTimeAfterTime2
  , ruleNthTimeOfTime
  , ruleNthTimeOfTime2
  , ruleOnANamedday
  , ruleOnDate
  , ruleOrdinalCycleAfterTime
  , ruleOrdinalCycleOfTime
  , ruleOrdinalQuarter
  , ruleOrdinalQuarterYear
  , rulePartofdayOfTime
  , ruleRelativeMinutesAfterpastIntegerHourofday
  , ruleRelativeMinutesTotillbeforeIntegerHourofday
  , ruleTheCycleAfterTime
  , ruleTheCycleBeforeTime
  , ruleTheDayofmonthNonOrdinal
  , ruleTheDayofmonthOrdinal
  , ruleTheIdesOfNamedmonth
  , ruleTheOrdinalCycleAfterTime
  , ruleTheOrdinalCycleOfTime
  , ruleThisCycle
  , ruleThisPartofday
  , ruleThisTime
  , ruleThisnextDayofweek
  , ruleTimeAfterNext
  , ruleTimeBeforeLast
  , ruleTimePartofday
  , ruleTimeofdayAmpm
  , ruleTimeofdayApproximately
  , ruleTimeofdayLatent
  , ruleTimeofdayOclock
  , ruleTimeofdaySharp
  , ruleTimeofdayTimeofdayInterval
  , ruleTimeofdayTimeofdayInterval2
  , ruleTonight
  , ruleUntilTimeofday
  , ruleUntilTimeofdayPostfix
  , ruleWeekend
  , ruleWithinDuration
  , ruleYear
  , ruleYearLatent
  , ruleYearLatent2
  , ruleYyyymmdd
  , ruleQuarterTotillbeforeIntegerHourofday
  , ruleHalfTotillbeforeIntegerHourofday
  , ruleQuarterAfterpastIntegerHourofday
  , ruleHalfAfterpastIntegerHourofday
  , ruleHourofdayQuarter
  , ruleHourofdayHalf
  , ruleTimezone
  ]
  ++ ruleInstants
  ++ ruleDaysOfWeek
  ++ ruleMonths
  ++ ruleSeasons
  ++ ruleHolidays
