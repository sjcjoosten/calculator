module Simplify where

import DataTypes

calculate :: [Law] -> Expr -> Calculation 
calculate laws e = Calc e (manyStep rws e)   
    where rws e = [Step name e’ | Law name eq <- laws, e’ <- rewrites eqn e] 

manyStep :: (Expr -> [Step]) -> Expr -> [Step]
manyStep rws e  
 = case steps of
    [] -> []        
    (o@(Step _ e) : _) -> o:manyStep rws e   
 where steps = rws e 

rewrites :: Equation -> Expr -> [Expr] 
rewrites eqn (Compose as)
   = map Compose (rewriteSeg eqn as ++ anyOne (rewritesA eqn) as) 

rewritesA eqn (Var v) = [] 
rewritesA eqn (Con k es) 
  = map (Con k) (anyOne (rewrites eqn) es)

rewritesSeg :: Equation -> [Atom] -> [[Atom]]
rewritesSeg (e1,e2) as  
 = [as1 ++ deCompose (apply subst e2) ++ as3      
   | (as1,as2,as3) <- split3 as      
   , subst <- match (e1, Compose as2) ] 

match :: (Expr,Expr) -> [Subst] 
match = concatMap (combine . map matchA) . alignments 

alignments :: (Expr,Expr) -> [([Atom],Expr)] 
alignments (Compose as, Compose bs) 
 = [zip as (map Compose bss) | bss <- splitsN (length as) bs] 

 matchA :: (Atom, Expr) -> [Subst] 
 matchA (Var v, e) = [unitSub v e] 
 matchA (Con k1 es1, Compose [Con k2 es2]) | k1 ==k2 
  = combine (map match (zip es1 es2))

type Subst = [(VarName,Expr)] 
type VarName = String 
unitSub :: VarName -> Expr -> Subst 
unitSub v e = [(v,e)]

apply :: Subst -> Expr -> Expr
apply sub (Compose as) = Compose (concatMap (applyA sub) as) 

applyA :: Subst -> Atom -> [Atom] 
applyA sub (Var v) = deCompose (binding sub v) 
applyA sub (Con k es) = [Con k (map (apply sub) es)] 

binding :: Subst -> VarName -> Expr 
binding ((v’,e):sub) v | v’ == v = e                                  
    | otherwise = binding sub v 
binding [] v = error “Could not find binding”

combine :: [[Subst]] -> [Subst]
combine = filterUnifiable . cp 
filterUnifiable = concatMap unifyAll 
unifyAll :: [Subst] -> [Subst] 
unifyAll = foldr f []   
    where f sub subs = concatMap (unify sub) subs

unify :: Subst -> Subst -> [Subst] 
unify s1 s2 = if compatible s1 s2 then [s1 ++ s2] else [] 

compatible :: Subst -> Subst -> Bool 
compatible sub1 sub2   
    = and [e1 == e2 | (v1, e1) <- sub1, (v2, e2) <-sub, v1==v2)