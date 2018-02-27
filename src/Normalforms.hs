module Normalforms (toNNF, toDNF, toCNF, isHornForm, toImplicationForm) where

import Prelude hiding (negate) 
import Parser
import MTree

{-
    Author          Jan Richter
    Date            27.02.2018
    Description     This module provides functions to transform MTrees 
                    into normal forms.

                    toNNF ~> Negative Normal Form
                    toDNF ~> Disjunctive Normal Form
                    toCNF ~> Conjunctive Normal Form 
                    isHornForm ~> Checks wether the argument is a valid
                               Horn Form 
                    toImplicationForm ~> Implicational Form 

                    All functions might produces errors when not used 
                    under following conditions: 

                    DNF requires the expression to be in NNF.
                    CNF requires the expression to be in NNF.
                    isHorn requires the expression to be in CNF.
                    implicF requires the expression to be in CNF.
-}

{-
    Functions Intended For External Use

    TODO alle fehler durch maybes ersetzen?

    Problem: Klammern / Negationen insb in Kombination werden nicht richtig
    erkannt, negationsauflösung funktioniert (demorgan)
-}

toNNF :: MTree -> MTree 
toNNF = dissolveNegation . dissolveImplication . dissolveEquivalence

toDNF :: MTree -> MTree 
toDNF n = if isDNF n then associativity n; else toDNF $ pullOutOr n  

toCNF :: MTree -> MTree 
toCNF n = if isCNF n then associativity n; else toCNF $ pullOutAnd n

isHornForm :: MTree -> Bool
isHornForm (Node And ns) = maximum (map f ns) <= 1 where 
    f (Leaf (Val False)) = 0
    f (Node Negate n)    = 0
    f (Leaf (Val True))  = 1
    f (Leaf (Var _))     = 1
    f (Node Or (n:ns))   = (f n) + (f (Node Or ns))
    f _                  = 2
isHornForm _             = False

toImplicationForm :: MTree -> MTree 
toImplicationForm (Node And ns) = Node And $ map toImplication ns

{-
    Convencience Functions
-}

-- assumes that tree is cnf <-> tree is nnf and does not contain 'or' nodes with 
-- 'and' children
isDNF :: MTree -> Bool 
isDNF (Leaf l)      = True 
isDNF (Node And ns) = foldl (\x y -> x && (not $ isDisjunction y) && isDNF y) True ns 
isDNF (Node _ ns)   = foldl (\x y -> x && isDNF y) True ns

-- assumes that tree is dnf <-> tree is nnf and does not contain 'and' nodes with 
-- 'or' children
isCNF :: MTree -> Bool 
isCNF (Leaf l)      = True 
isCNF (Node Or ns)  = foldl (\x y -> x && (not $ isConjunction y) && isCNF y) True ns 
isCNF (Node _ ns)   = foldl (\x y -> x && isCNF y) True ns

{-
    Tree Transforming Functions
-}

negate :: MTree -> MTree 
negate n@(Leaf _)                   = Node Negate [n]
negate (Node Negate [n@(Leaf _)])   = n 
negate (Node Negate [n@(Node _ _)]) = n
negate n@(Node _ _)                 = Node Negate [n] 
 
dissolveEquivalence :: MTree -> MTree 
dissolveEquivalence n@(Leaf _)            = n 
dissolveEquivalence (Node Equiv (n:m:[])) = 
    let left = Node Impl [n,m]
        right = Node Impl [m,n]
    in  Node And [left, right]
dissolveEquivalence (Node Equiv ns)       = 
    let n = head ns 
        m = Node Equiv $ tail ns
        left = Node Impl [n,m]
        right = Node Impl [m,n]
        left' = dissolveEquivalence left 
        right' = dissolveEquivalence right
    in  Node And [left', right'] 
dissolveEquivalence (Node op ns)          = 
    Node op $ map dissolveEquivalence ns

dissolveImplication :: MTree -> MTree 
dissolveImplication n@(Leaf _)     = n 
dissolveImplication (Node Impl ns) = Node Or $ f [] ns where 
    f xs [y]     = xs ++ [y]
    f xs (y:ys)  = f (map negate $ xs ++ [y]) ys 
dissolveImplication (Node op ns)   = Node op $ map dissolveImplication ns 

-- assumes argument does not contain equivalences & implications
dissolveNegation :: MTree -> MTree 
dissolveNegation (Node Negate [(Node And ns)])     = Node Or $ map (dissolveNegation . negate) ns
dissolveNegation (Node Negate [(Node Or ns)])      = Node And $ map (dissolveNegation . negate) ns 
dissolveNegation (Node Negate [(Node Negate [n])]) = n 
dissolveNegation n                                 = n 
   
-- assumes argument is in negation normal form / -> dnf
pullOutOr :: MTree -> MTree
pullOutOr n@(Leaf _)      = n
pullOutOr n@(Node And ns) = 
    if not $ and $ map (flip hasOperator And) ns 
        then let (Node And ns) = associativity n
                 disjunction   = head $ fst $ splitAtOp ns Or 
                 rest          = snd $ splitAtOp ns Or
                 toConjunct1   = head $ children disjunction
                 toConjunct2   = tail $ children disjunction
                 conjunction1  = Node And $ rest ++ [toConjunct1]
                 conjunction2  = Node And $ rest ++ toConjunct2
             in Node Or [conjunction1, conjunction2]
    else Node And $ map pullOutOr ns
pullOutOr (Node op ns)     = Node op $ map pullOutOr ns

-- assumes argument is in negation normal form / -> cnf
pullOutAnd :: MTree -> MTree 
pullOutAnd n@(Leaf _)     = n
pullOutAnd n@(Node Or ns) = 
    if not $ or $ map (flip hasOperator Or) ns 
        then let (Node Or ns)  = associativity n
                 conjunction   = head $ fst $ splitAtOp ns And 
                 rest          = snd $ splitAtOp ns And
                 toDisjunct1   = head $ children conjunction
                 toDisjunct2   = tail $ children conjunction
                 disjunction1  = Node Or $ rest ++ [toDisjunct1]
                 disjunction2  = Node Or $ rest ++ toDisjunct2
             in Node And [disjunction1, disjunction2]
    else Node Or $ map pullOutAnd ns
pullOutAnd (Node op ns)   = Node op $ map pullOutAnd ns

-- dissolves redundant brackets
associativity :: MTree -> MTree 
associativity n@(Leaf _)       = n 
associativity (Node op (n:ns)) = 
    if hasOperator n op 
        then associativity (Node op $ ns ++ (children n))
    else Node op $ n:(map associativity ns)

toImplication :: MTree -> MTree 
toImplication (Node Or ns) = 
    let premise   = if (length $ allNegatives ns) == 0 
                        then Leaf (Val True); 
                    else Node And $ allNegatives ns 
        conclusio = if (length $ allPositives ns) == 0 
                        then Leaf (Val False); 
                    else Node And $ allPositives ns 
    in Node Impl [premise, conclusio]

allNegatives :: [MTree] -> [MTree]
allNegatives = filter (not . isPositive)

allPositives :: [MTree] -> [MTree]
allPositives = filter isPositive

-- assumes argument does not have child operators
isPositive :: MTree -> Bool 
isPositive (Leaf (Val True))  = True 
isPositive (Leaf (Val False)) = False 
isPositive (Leaf _ )          = True
isPositive (Node Negate [n])  = not $ isPositive n 