{-# LANGUAGE UnicodeSyntax #-}
module Main where

-- import Data.HMM
import System.IO hiding (putStr)
import System.Directory
-- import Data.Array
import Text.XML.HXT.Core
import Prelude hiding (words, putStr)
import qualified Data.Map as M
import Parse

type ℤ = Int
type ℚ = Double

freqMap ∷ Ord a ⇒ [a] → M.Map a ℤ
freqMap unigrams = populate M.empty unigrams
  where populate ∷ Ord a ⇒ M.Map a ℤ → [a] → M.Map a ℤ
        populate m [] = m
        populate m (x:xs) = let freq = (M.findWithDefault 0 x m) ∷ ℤ
                            in populate (M.insert x (freq + 1) m) xs

-- | Probability of a, given b.
-- | TODO: Implement
probability :: POS → POS → ℚ
probability a b = undefined

main ∷ IO ()
main = do
  files ← getDirectoryContents "tb_uni"
  let fileNames = drop 2 . take 100 $ map ("tb_uni/" ++) files
  pairList ← mapM runX $ map getWords fileNames
      -- First we need to get POS types from the textual representation in the
      -- corpus. the `pairList` that we have right now is a list of
      -- list of tuples. We call `extractPOS` on the `snd` element of
      -- each tuple.
  let tagsList = map (\xs → map (extractPOS . snd) xs) pairList
      -- Now let us append a beginning of sentence POS to each of the lists
      -- in tagsList and denote this with tagsList'.
      tagsList'      ∷ [[POS]]
      tagsList'      = map ((:) Start) tagsList
      -- If we concat all the lists, we're left with just list of tags.
      tags           = foldr (++) [] tagsList'
      tagBigrams     = [(tags !! i, tags !! (i+1))
                         | i ← [0..length tags - 2]]
      tagBigramFreqs = freqMap tagBigrams
      tagFreqs       = freqMap tags
  print $ tagBigramFreqs M.! (Noun, Verb)
  print $ tagFreqs M.! Noun
