{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}

module Ormolu.Printer.Meat.Declaration.Default
  ( p_defaultDecl,
  )
where

import GHC
import Ormolu.Printer.Combinators
import Ormolu.Printer.Meat.Type

p_defaultDecl :: DefaultDecl GhcPs -> R ()
p_defaultDecl (DefaultDecl NoExtField ts) = do
  txt "default"
  breakpoint
  inci . parens N $
    sep commaDel (sitcc . located' p_hsType) ts
