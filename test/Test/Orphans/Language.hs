{-# OPTIONS_GHC -fno-warn-orphans #-}

module Test.Orphans.Language () where



import qualified Data.Map              as M
import           Data.Monoid
import           Data.Text             (Text)
import qualified Data.Text             as T
import           Test.Tasty.QuickCheck

import           Stg.Language

--------------------------------------------------------------------------------
-- Helper functions
allEnums :: (Enum a, Bounded a) => Gen a
allEnums = elements [minBound ..]

arbitrary1
    :: Arbitrary a
    => (a -> g)
    -> Gen g
arbitrary1 f = f <$> arbitrary

arbitrary2
    :: (Arbitrary a, Arbitrary b)
    => (a -> b -> g)
    -> Gen g
arbitrary2 f = f <$> arbitrary <*> arbitrary

arbitrary3
    :: (Arbitrary a, Arbitrary b, Arbitrary c)
    => (a -> b -> c -> g)
    -> Gen g
arbitrary3 f = f <$> arbitrary <*> arbitrary <*> arbitrary

arbitrary4
    :: (Arbitrary a, Arbitrary b, Arbitrary c, Arbitrary d)
    => (a -> b -> c -> d -> g)
    -> Gen g
arbitrary4 f = f <$> arbitrary <*> arbitrary <*> arbitrary <*> arbitrary

lowerChar :: Gen Text
lowerChar = T.singleton <$> elements ['a'..'z']

upperChar :: Gen Text
upperChar = T.singleton <$> elements ['A'..'Z']

extendedLetters :: Gen Text
extendedLetters = T.pack <$> listOf extendedLetter
  where
    extendedLetter :: Gen Char
    extendedLetter = elements (['a'..'z'] ++ ['A'..'Z'] ++ ['0'..'9'] ++ "\'_")

--------------------------------------------------------------------------------
-- Instances

instance Arbitrary Program where
    arbitrary = arbitrary1 Program
    shrink = genericShrink

instance Arbitrary Binds where
    arbitrary = do
        xs <- listOf1 arbitrary
        pure (Binds (M.fromList xs))
    shrink (Binds b) = (map (Binds . M.fromList) . genericShrink . M.toList) b

instance Arbitrary LambdaForm where
    arbitrary = arbitrary4 LambdaForm
    shrink = genericShrink

instance Arbitrary UpdateFlag where
    arbitrary = allEnums
    shrink = genericShrink

instance Arbitrary Rec where
    arbitrary = allEnums
    shrink = genericShrink

instance Arbitrary Expr where
    arbitrary = oneof
        [ arbitrary3 Let
        , arbitrary2 Case
        , arbitrary2 AppF
        , arbitrary2 AppC
        , arbitrary3 AppP
        , arbitrary1 Lit ]
    shrink = genericShrink

instance Arbitrary Alts where
    arbitrary = oneof [arbitrary1 Algebraic, arbitrary1 Primitive]
    shrink = genericShrink

instance Arbitrary AlgebraicAlts where
    arbitrary = AlgebraicAlts <$> listOf1 arbitrary <*> arbitrary
    shrink = genericShrink

instance Arbitrary PrimitiveAlts where
    arbitrary = PrimitiveAlts <$> listOf1 arbitrary <*> arbitrary
    shrink = genericShrink

instance Arbitrary AlgebraicAlt where
    arbitrary = arbitrary3 AlgebraicAlt
    shrink = genericShrink

instance Arbitrary PrimitiveAlt where
    arbitrary = arbitrary2 PrimitiveAlt
    shrink = genericShrink

instance Arbitrary DefaultAlt where
    arbitrary = oneof [arbitrary1 DefaultNotBound, arbitrary2 DefaultBound]
    shrink = genericShrink

instance Arbitrary Literal where
    arbitrary = arbitrary1 Literal
    shrink = genericShrink

instance Arbitrary PrimOp where
    arbitrary = allEnums
    shrink = genericShrink

instance Arbitrary Var where
    arbitrary = do
        x <- lowerChar
        xs <- extendedLetters
        (pure . Var) (x <> xs)
    shrink (Var var) = (map (Var . T.pack) . genericShrink . T.unpack) var

instance Arbitrary Atom where
    arbitrary = oneof [arbitrary1 AtomVar, arbitrary1 AtomLit]
    shrink = genericShrink

instance Arbitrary Constr where
    arbitrary = do
        x <- upperChar
        xs <- extendedLetters
        (pure . Constr) (x <> xs)
    shrink (Constr constr) = (map (Constr . T.pack) . genericShrink . T.unpack) constr
