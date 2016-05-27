{-# LANGUAGE OverloadedLists   #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}

module Stg.Prelude.List (
    nil,
    concat2,
    reverse,
    foldl,
    foldl',
    foldr,
    iterate,
    cycle,
    take,
    filter,
    repeat,
    replicate,
    sort,
    map,
    equals_List_Int,
    length,
    zip,
    zipWith,

    -- * Convenience
    listOfNumbers,
) where



import qualified Prelude as P

import qualified Data.Map    as M
import           Data.Monoid
import           Data.Text   (Text)
import qualified Data.Text   as T

import Stg.Language
import Stg.Parser.QuasiQuoter
import Stg.Util

import Stg.Prelude.Number as Num

-- $setup
-- >>> :set -XOverloadedStrings
-- >>> import Stg.Language.Prettyprint
-- >>> import qualified Data.Text.IO   as T



nil, concat2, foldl, foldl', foldr, iterate, cycle, take, filter :: Program
repeat, replicate, sort, map, equals_List_Int, length, zip, zipWith :: Program
reverse :: Program


-- | The empty list as a top-level closure.
--
-- @
-- nil : [a]
-- @
nil = [program| nil = \ -> Nil |]

-- | Concatenate two lists. Haskell's @(++)@.
--
-- @
-- concat2 : [a] -> [a] -> [a]
-- @
concat2 = [program|
    concat2 = \xs ys -> case xs of
        Nil -> ys;
        Cons x xs' ->
            let rest = \(xs' ys) => concat2 xs' ys
            in Cons x rest;
        badList -> Error_concat2 badList
    |]

-- | Lazy left list fold. Provided mostly for seeing how it causes stack
-- overflows.
--
-- @
-- foldl : (b -> a -> b) -> b -> [a] -> b
-- @
foldl = [program|
    foldl = \f acc xs -> case xs of
        Nil -> acc;
        Cons y ys ->
            let acc' = \(f acc y) => case f acc y of v -> v
            in foldl f acc' ys;
        badList -> Error_foldl badList
    |]

-- | Strict left list fold.
--
-- @
-- foldl' : (b -> a -> b) -> b -> [a] -> b
-- @
foldl' = [program|
    foldl' = \f acc xs -> case xs of
        Nil -> acc;
        Cons y ys -> case f acc y of
            acc' -> foldl' f acc' ys;
        badList -> Error_foldl' badList
    |]

-- | Right list fold.
--
-- @
-- foldr : (a -> b -> b) -> b -> [a] -> b
-- @
foldr = [program|
    foldr = \f z xs -> case xs of
        Nil -> z;
        Cons y ys ->
            let rest = \(f z ys) => foldr f z ys
            in f y rest;
        badList -> Error_foldr badList
    |]

-- | Build a list by repeatedly applying a function to an initial value.
--
-- @
-- iterate f x = [x, f x, f (f x), ...]
-- @
--
-- @
-- iterate : (a -> a) -> a -> [a]
-- @
iterate = [program|
    iterate = \f x ->
        letrec
            fx = \(f x) => f x;
            rest = \(f fx) => iterate f fx
        in Cons x rest
    |]

-- | Infinite list created by repeating an initial (non-empty) list.
--
-- @
-- cycle [x,y,z] = [x,y,z, x,y,z, x,y,z, ...]
-- @
--
-- @
-- cycle : [a] -> [a]
-- @
cycle = concat2 <> [program|
    cycle = \xs ->
        letrec xs' = \(xs xs') => concat2 xs xs'
        in xs'
    |]

-- | Take n elements form the beginning of a list.
--
-- @
-- take 3 [1..] = [1,2,3]
-- @
--
-- @
-- take : Int -> [a] -> [a]
-- @
take = [program|
    take = \n ->
        letrec
            takePrim = \(takePrim) nPrim xs ->
                case nPrim of
                    0# -> Nil;
                    default -> case xs of
                        Nil -> Nil;
                        Cons x xs ->
                            let rest = \(takePrim xs nPrim) => case -# nPrim 1# of
                                    nPrimPred -> takePrim nPrimPred xs
                            in Cons x rest;
                        badList -> Error_take_badList badList
        in case n of
            Int# nPrim -> takePrim nPrim;
            badInt -> Error_take_badInt badInt
    |]

-- | Keep only the elements for which a predicate holds.
--
-- @
-- filter even [1..] = [2, 4, 6, ...]
-- @
--
-- @
-- filter : (a -> Bool) -> [a] -> [a]
-- @
filter = [program|
    filter = \p xs -> case xs of
        Nil -> Nil;
        Cons x xs' -> case p x of
            False -> filter p xs';
            True ->
                let rest = \(p xs') => filter p xs'
                in Cons x rest;
            badBool -> Error_filter_1 badBool;
        badList -> Error_filter_2 badList
    |]

-- | reverse a list.
--
-- @
-- reverse [1,2,3] = [3,2,1]
-- @
--
-- @
-- reverse : [a] -> [a]
-- @
reverse = nil <> [program|
    reverse = \xs ->
        letrec
            reverse' = \(reverse') xs ys ->
                case xs of
                    Nil -> ys;
                    Cons x xs ->
                        let yxs = \(x ys) -> Cons x ys
                        in reverse' xs yxs;
                    badList -> Error_reverse badList
        in reverse' xs nil
    |]

-- | Repeat a single element infinitely.
--
-- @
-- repeat 1 = [1, 1, 1, ...]
-- @
--
-- @
-- repeat : a -> [a]
-- @
repeat = [program|
    repeat = \x ->
        letrec xs = \(x xs) -> Cons x xs
        in xs
    |]

-- | Repeat a single element a number of times.
--
-- @
-- replicate 3 1 = [1, 1, 1]
-- @
--
-- @
-- replicate : Int -> a -> [a]
-- @
replicate = [program|
    replicate = \n x ->
        letrec
            replicateXPrim = \(replicateXPrim x) nPrim ->
                case ># nPrim 0# of
                    0# -> Nil;
                    default ->
                        let rest = \(replicateXPrim nPrim) ->
                                case -# nPrim 1# of
                                    nPrimPred -> replicateXPrim nPrimPred
                        in Cons x rest
        in case n of
            Int# nPrim -> replicateXPrim nPrim;
            badInt -> Error_replicate badInt
    |]

-- | That Haskell sort function often misleadingly referred to as "quicksort".
--
-- @
-- sort : [Int] -> [Int]
-- @
sort = mconcat [leq_Int, gt_Int, filter, concat2] <> [program|
    sort = \xs -> case xs of
        Nil -> Nil;
        Cons pivot xs' ->
            let beforePivotSorted = \(pivot xs') =>
                    letrec
                        atMostPivot = \(pivot) y -> leq_Int  y pivot;
                        beforePivot = \(xs' atMostPivot) => filter atMostPivot xs'
                    in sort beforePivot;

                afterPivotSorted = \(pivot xs') =>
                    letrec
                        moreThanPivot = \(pivot) y -> gt_Int y pivot;
                        afterPivot    = \(xs' moreThanPivot) => filter moreThanPivot  xs'
                    in sort afterPivot
            in  let fromPivotOn = \(pivot afterPivotSorted) -> Cons pivot afterPivotSorted
                in concat2 beforePivotSorted fromPivotOn;
        badList -> Error_sort badList
    |]

-- | Apply a function to each element of a list.
--
-- @
-- map : (a -> b) -> [a] -> [b]
-- @
map = [program|
    map = \f list -> case list of
        Nil       -> Nil;
        Cons x xs -> let fx  = \(f x)  => f x;
                         fxs = \(f xs) => map f xs
                     in Cons fx fxs;
        badList -> Error_map badList
    |]

-- | Generate a list of numbers.
--
-- Also demonstrate nicely how much overhead seemingly simple lists have.
--
-- >>> let ppr ast = T.putStrLn (prettyprintPlain ast)
-- >>> ppr (listOfNumbers "list" [1, -2, 3])
-- list = \ => letrec
--                 int_'2 = \ -> Int# -2#;
--                 int_1 = \ -> Int# 1#;
--                 int_3 = \ -> Int# 3#;
--                 list_ix0_int_1 = \(int_1 list_ix1_int_'2) => Cons int_1 list_ix1_int_'2;
--                 list_ix1_int_'2 = \(int_'2 list_ix2_int_3) => Cons int_'2 list_ix2_int_3;
--                 list_ix2_int_3 = \(int_3) => Cons int_3 nil
--             in list_ix0_int_1;
-- nil = \ -> Nil
listOfNumbers
    :: T.Text      -- ^ Name of the list in the STG program
    -> [P.Integer] -- ^ Entries
    -> Program
-- TODO: The paper mentions a more efficient construction of literal source
-- lists that is "usually superior".
listOfNumbers name [] = nil <> Program (Binds [(Var name, [lambdaForm| \ -> nil |])])
listOfNumbers name ints = nil <>
    Program (Binds [
        ( Var name
        , LambdaForm [] Update []
            (Let Recursive
                (Binds (M.fromList (intBinds <> listBinds)))
                (AppF (Var (listBindName 0 (P.head ints))) []) ))])
  where
    intBinds = P.map intBind ints
    listBinds = P.zipWith3 listBind
                           [0..]
                           ints
                           (P.zipWith listBindName [1..] (P.tail ints) <> ["nil"])

    listBind ix i tailName =
        ( Var (listBindName ix i)
        , LambdaForm ([Var (intName i)] <> [ Var tailName | tailName P./= "nil"])
                     NoUpdate -- Standard constructors are not updatable
                     []
                     (AppC (Constr "Cons")
                           [AtomVar (Var (intName i)), AtomVar (Var tailName)] ))
    listBindName :: P.Integer -> P.Integer -> Text
    listBindName ix i = "list_ix" <> show' ix <> "_" <> intName i

    intBind :: P.Integer -> (Var, LambdaForm)
    intBind i =
        ( Var (intName i)
        , LambdaForm [] NoUpdate []
                     (AppC (Constr "Int#") [AtomLit (Literal i)]))

    intName :: P.Integer -> T.Text
    intName i = "int_" <> sign <> show' (P.abs i)
      where
        sign | i P.< 0 = "'"
             | P.otherwise = ""

-- | Equality of lists of integers.
--
-- @
-- equals_List_Int : [Int] -> [Int] -> Bool
-- @
equals_List_Int = Num.eq_Int <> [program|
    equals_List_Int = \xs ys ->
        case xs of
            Nil -> case ys of
                Nil -> True;
                Cons y ys' -> False;
                badList -> Error_listEquals badList;
            Cons x xs' -> case ys of
                Nil -> False;
                Cons y ys' -> case eq_Int x y of
                    True  -> equals_List_Int xs' ys';
                    False -> False;
                    badBool -> Error_listEquals_1 badBool;
                badList -> Error_listEquals_2 badList;
            badList -> Error_listEquals_3 badList
    |]

-- | Length of a list.
--
-- @
-- length : [a] -> Int
-- @
length = [program|
    length = \ =>
        letrec
            length' = \(length') n xs -> case xs of
                Nil -> Int# n;
                Cons y ys -> case +# n 1# of
                    n' -> length' n' ys;
                badList -> Error_length badList
        in length' 0#
    |]

-- | Zip two lists into one. If one list is longer than the other ignore the
-- exceeding elements.
--
-- @
-- zip [1,2,3,4,5] [10,20,30] ==> [(1,10),(2,20),(3,30)]
--
-- zip xs ys = zipWith Tuple xs ys
-- @
--
-- @
-- zip : [a] -> [b] -> [(a,b)]
-- @
zip = [program|
    zip = \xs ys -> case xs of
        Nil -> Nil;
        Cons x xs' -> case ys of
            Nil -> Nil;
            Cons y ys' ->
                let tup  = \(x y)     -> Tuple x y;
                    rest = \(xs' ys') => zip xs' ys'
                in Cons tup rest;
            badList -> Error_zip badList;
        badList -> Error_zip badList
    |]

-- | Zip two lists into one using a user-specified combining function.
-- If one list is longer than the other ignore the exceeding elements.
--
-- @
-- zipWith (+) [1,2,3,4,5] [10,20,30] ==> [11,22,33]
--
-- zipWith f xs ys = map f (zip xs ys)
-- @
--
-- @
-- zipWith : (a -> b -> c) -> [a] -> [b] -> [c]
-- @
zipWith = [program|
    zipWith = \f xs ys -> case xs of
        Nil -> Nil;
        Cons x xs' -> case ys of
            Nil -> Nil;
            Cons y ys' ->
                let fxy = \(f x y) => f x y;
                    rest = \(f xs' ys') => zipWith f xs' ys'
                in Cons fxy  rest;
            badList -> Error_zipWith badList;
        badList -> Error_zipWith badList
    |]
