{-# LANGUAGE UnicodeSyntax #-}

module Main where

import           Data.Array           (Array, listArray)
import           Data.HMM             (HMM (..), viterbi)
import qualified Data.Map             as M
import           Data.List            (intercalate)
import           Data.Number.LogFloat
import           Parse
import           Prelude              hiding (putStr, words, lines)
import           System.Directory
-- import           System.IO (putStr)
import           Text.XML.HXT.Core

type ℤ = Int      -- The integer type `Int` will be denoted by ℤ.
type ℚ = Double   -- The double type will be denoted by ℚ.
type 𝓛 = LogFloat -- Log-domain numbers to prevent underflow.

ε ∷ Double
ε = encodeFloat 1 $ fst  r - ds
  where r  = floatRange (0.1 :: Double)
        ds = floatDigits (0.1 :: Double)

sample₁ ∷ Array Int String
sample₁ = listArray (0, 4) [ "gözleri"
                           , "kor"
                           , "gibi"
                           , "yanıyordu"
                           , "."]

sample₂ ∷ Array Int String
sample₂ = listArray (0, 3) [ "adam"
                           , "yine"
                           , "geldi"
                           , "."
                           ]

sample₃ ∷ Array Int String
sample₃ = listArray (0, 4) [ "güzel"
                           , "kız"
                           , "mutlu"
                           , "gözüküyordu"
                           , "."]

sample₄ ∷ Array Int String
sample₄   = listArray (0, 5) [ "renksiz"
                             , "yeşil"
                             , "fikirler"
                             , "sessizce"
                             , "uyuyor"
                             , "."
                             ]

sample₅ ∷ Array Int String
sample₅   = listArray (0, 3) [ "dostlar"
                             , "beni"
                             , "hatırlasın"
                             , "."
                             ]

sample₆ ∷ Array Int String
sample₆ = listArray (0, 25) [ "Cebren"
                            , "ve"
                            , "hile"
                            , "ile"
                            , "aziz"
                            , "vatanın"
                            , ","
                            , "bütün"
                            , "kaleleri"
                            , "zaptedilmiş"
                            , "bütün"
                            , "tersanelerine"
                            , "girilmiş"
                            , ","
                            , "bütün"
                            ,"orduları"
                            ,"dağıtılmış"
                            , "ve"
                            , "memleketin"
                            ,"her"
                            ,"köşesi"
                            ,"bilfiil"
                            ,"işgal"
                            ,"edilmiş"
                            ,"olabilir"
                            ,"."
                            ]

pretty ∷ Array Int String → [POS] → IO ()
pretty ws ps = let lines = (\n → replicate n '-') <$> (length <$> ws)
                   align ∷ String → String → String
                   align w t = let
                     n      = max 0 (length w - (length t)) `div` 2
                     spaces = replicate n ' '
                     in spaces ++ t ++ spaces
                   wsList   = foldr (:) [] ws
                   pStrings = map show ps
               in do putStrLn $ intercalate " " wsList
                     putStrLn $ foldr (++) " "   $ (++ " ") <$> lines
                     putStrLn $ intercalate "  " $
                       zipWith align wsList pStrings

table ∷ Array Int String → [POS] → String
table ws ps = let makeItem w = "<th align=\"center\">" ++ w ++ "</th>"
                  makeRow xs = "<tr>" ++ concat (map makeItem xs) ++ "</tr>"
                  wRow = makeRow $ foldr (:) [] ws
                  pRow = makeRow $ map show ps
              in    "<html><table>"
                 ++ wRow
                 ++ pRow
                 ++ "</table></html>"

freqMap ∷ Ord a ⇒ [a] → M.Map a ℤ
freqMap unigrams = populate M.empty unigrams
  where populate ∷ Ord a ⇒ M.Map a ℤ → [a] → M.Map a ℤ
        populate m [] = m
        populate m (x:xs) = let freq = (M.findWithDefault 0 x m) ∷ ℤ
                            in populate (M.insert x (freq + 1) m) xs

--  | Takes in a tuple (x, y) (i.e., a bigram), and takes in two frequency maps
--    c₁ and c₂, c₁ for counting all the occurrences of x and the other for
--    counting the number of bigrams.
probability ∷ (Ord a, Ord b) ⇒ (a, b) → M.Map a ℤ → M.Map (a, b) ℤ → 𝓛
probability (x, y) c₁ c₂ = if xCount == 0 || yCount == 0
                           then logFloat ε
                           else (logFloat yCount) / (logFloat xCount)
  where yCount = fromIntegral (M.findWithDefault 0 (x, y) c₂) ∷ ℚ
        xCount = fromIntegral (M.findWithDefault 0 x c₁) ∷ ℚ

main ∷ IO ()
main = do
  files ← getDirectoryContents "tb_uni"
  let fileNames = drop 2 . take 1500 $ map ("tb_uni/" ++) files
  pairList ← mapM runX $ map getWords fileNames
  let taggedWordsList  = map parseTupleList pairList
      taggedWords      = concat taggedWordsList
      (ws, ts)         = unzip taggedWords
      -- For computing the probability of word-tag pair.
      taggedWordFreqs  = freqMap taggedWords
      wordFreqs        = freqMap ws
      tagFreqs         = freqMap ts
      -- For computing the probability of tag bigram
      tagBigrams       = [(ts !! i, ts !! (i+1)) | i ← [0 .. (length ts)-2]]
      tagBigramFreqs   = freqMap tagBigrams
      -- We will use these to create our HMM.
      transFn s₁ s₂     = probability (s₁, s₂) tagFreqs tagBigramFreqs
      outFn s e        = probability (e, s) wordFreqs taggedWordFreqs
      initStatesFreqs  = freqMap  $ map (head . map snd) taggedWordsList
      initProbFn s     = let count  = M.findWithDefault 0 s initStatesFreqs
                             count' = fromIntegral count
                             n      = fromIntegral $ length taggedWordsList
                         in logFloat $ count' / n
      possibleTags     = [Noun .. Unknown]
      newHMM           = HMM { states      = possibleTags ∷ [POS]
                             , events      = ws ∷ [String]
                             , initProbs   = initProbFn
                             , transMatrix = transFn
                             , outMatrix   = outFn}
  writeFile "model.hmm" (show newHMM)
  -- putStrLn "Creating the model..."
  putStrLn $ table sample₆ $ viterbi newHMM sample₆
  -- putStr "\n"
  -- pretty sample₂ $ viterbi newHMM sample₂
  -- putStr "\n"
  -- pretty sample₃ $ viterbi newHMM sample₃
  -- putStr "\n"
  -- pretty sample₄ $ viterbi newHMM sample₄
  -- putStr "\n"
  -- pretty sample₅ $ viterbi newHMM sample₅
  -- putStr "\n"
  -- pretty sample₆ $ viterbi newHMM sample₆
