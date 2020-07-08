{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE RecordWildCards    #-}
{-# LANGUAGE RecursiveDo        #-}
{-# LANGUAGE TemplateHaskell    #-}

module Potato.Flow.New.Cmd (
  PFCmdTag(..)
  , PFCmd

) where

import           Relude

import           Reflex
import           Reflex.Data.ActionStack

import           Potato.Flow.Math
import           Potato.Flow.Reflex.Types

import qualified Data.Dependent.Map       as DM
import qualified Data.Dependent.Sum       as DS
import qualified Text.Show

data PFCmdTag a where
  -- LayerPos indices are as if all elements already exist in the map
  PFCNewElts :: PFCmdTag (NonEmpty SuperSEltLabel)
  -- LayerPos indices are the current indices of elements to be removed
  PFCDeleteElts :: PFCmdTag (NonEmpty SuperSEltLabel)
  --PFCMove :: PFCmdTag t (NonEmpty LayerPos, LayerPos)
  --PFCDuplicate :: PFCmdTag t [REltId]
  PFCManipulate :: PFCmdTag (ControllersWithId)
  PFCResizeCanvas :: PFCmdTag DeltaLBox

instance Text.Show.Show (PFCmdTag a) where
  show PFCNewElts      = "PFCNewElts"
  show PFCDeleteElts   = "PFCDeleteElts"
  show PFCManipulate   = "PFCManipulate"
  show PFCResizeCanvas = "PFCResize"

type PFCmd = DS.DSum PFCmdTag Identity