{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Oczor.Infer.Substitutable where

import ClassyPrelude
import Oczor.Syntax.Syntax
import Oczor.Utl

newtype Subst = Subst (Map String TypeExpr)
  deriving (Eq, Ord, Show, Monoid)

emptySubst :: Subst
emptySubst = mempty

composeSubst :: Subst -> Subst -> Subst
composeSubst s@(Subst s1) (Subst s2) = Subst $ union (map (apply s) s2) s1

composeSubstList :: [Subst] -> Subst
composeSubstList =  foldr (flip composeSubst) emptySubst

class Substitutable a where
  apply :: Subst -> a -> a
  ftv   :: a -> Set String


instance (Substitutable a) => Substitutable (ExprF a) where
  apply s x = map (apply s) x

makeType :: TypeExpr -> [TypeExpr] -> TypeExpr
-- makeType x y | traceArgs ["makeType", show x, show y] = undefined
makeType (TypePoly param body) arg = 
  if al > pl then error "makeType la > pl"
  else if al == pl then r
  else TypePoly (param & drop al) r
  where
    pl = length param
    al = length arg
    x = zip param arg & map (\((TypeVar x), y) -> (x,y))
    subst = Subst (x & mapFromList)
    r = apply subst body
makeType x arg = error $ unwords ["makeType", show x, show arg]

normalizeTypeRow t@(TypeRowF x y) =
  case x of
    TypeVar {} -> TypeRow x (ordNub y)
    _ -> x

normalizeTypeConstrains x@(TypeConstrains clist t) = 
  if onull newClist then t else TypeConstrains newClist t 
  where
  vars = ftv t & setToList <&> TypeVar
  newClist = clist & filter (\(var,_) -> oelem var vars)

instance Substitutable TypeExpr where

  -- apply x y | traceArgs ["apply typeExpr", show x, show y] = undefined
  apply (Subst s) x = cata alg x -- TODO add typepoly case
    where
      alg = \case
        x@TypeConstrainsF {} -> normalizeTypeConstrains $ moveConstrainsOnTop (Fix x)
        TypeApplyF (TypeApply body param1) param2 -> TypeApply body (param1 ++ param2)
        t@TypeRowF {} -> normalizeTypeRow t
        t@(TypeVarF x) -> findWithDefault (Fix t) x s
        x -> Fix x

  ftv = setFromList . getTypeVars

instance Substitutable Scheme where
  apply (Subst s) (Forall as t)   = Forall as $ apply s' t
                            where s' = Subst $ foldr deleteMap s as
  ftv (Forall as t) = difference (ftv t) (setFromList as)

instance Substitutable a => Substitutable [a] where
  apply = map . apply
  ftv   = foldr (union . ftv) mempty


