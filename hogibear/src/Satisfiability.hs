module Satisfiability where 

import Normalforms
import MTree

{-
    Author          Jan Richter
    Date            27.02.2018
    Description     This module provides methods to test if a given
                    logical expression is satisfiable. 
-}

{-
    Functions Intended For External Use
-}

-- empty -> not satisfiable; [a,b,c] -> a b c = 1 else 0
hornSatisfiable :: MTree -> [String]
hornSatisfiable = (markAlg []) . toImplicationForm

--renamableHornSat :: MTree -> [(String, String)] 

{-
    Horn Satisfiability Algorithm
-}

markAlg :: [String] -> MTree -> [String] 
markAlg vs n@(Node And ns) 
    | ((toMark vs n) == []) 
      && (not $ contradicts vs n) = vs
    | otherwise = markAlg (vs ++ (toMark vs n)) n
markAlg _ n@(Node Impl [_,_]) = toMark [] n
markAlg _ _                   = []

toMark :: [String] -> MTree -> [String] 
toMark vs (Node Impl [m,n]) 
    | isTrueOrMarked vs m   = removeList (getVariables n) vs 
    | otherwise             = []
toMark vs (Node And ns)     = concatMap (toMark vs) ns 
toMark _ _                  = []

isTrueOrMarked :: [String] -> MTree -> Bool 
isTrueOrMarked vs (Leaf (Val True))  = True 
isTrueOrMarked vs (Leaf (Val False)) = False 
isTrueOrMarked vs (Leaf (Var s))     = elem s vs 
isTrueOrMarked vs (Node _ ns)        = and $ map (isTrueOrMarked vs) ns

containsFalse :: MTree -> Bool
containsFalse (Leaf (Val False)) = True 
containsFalse (Leaf _)           = False 
containsFalse (Node _ ns)        = or $ map containsFalse ns

contradicts :: [String] -> MTree -> Bool
contradicts vs (Node Impl [m,n]) = (isTrueOrMarked vs m) && (containsFalse n)
contradicts vs (Node And ns)     = or $ map (contradicts vs) ns 

getVariables :: MTree -> [String]
getVariables (Leaf (Val _)) = []
getVariables (Leaf (Var s)) = [s]
getVariables (Node _ ns)    = concatMap getVariables ns

removeList :: Eq a => [a] -> [a] -> [a]
removeList xs ys = foldl (\x y -> if elem y ys then x; else x ++ [y]) [] xs
