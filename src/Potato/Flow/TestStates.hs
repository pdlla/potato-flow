{-# LANGUAGE RecordWildCards #-}
{-# OPTIONS_GHC -fno-warn-type-defaults #-}
module Potato.Flow.TestStates (
  folderStart
  , folderEnd
  , someSEltLabel
  , someSCanvas
  , defaultCanvasLBox
  , someOwlElt
  , pFState_to_owlPFState
  , owlPFState_fromSElts
  , owlpfstate_someValidState1
  , owlpfstate_someInvalidState1
  , owlpfstate_someInvalidState2
  , owlpfstate_basic0
  , owlpfstate_basic1
  , owlpfstate_basic2
  , owlpfstate_zero
) where

import           Relude

import           Potato.Flow
import           Potato.Flow.Deprecated.TestStates
import           Potato.Flow.Deprecated.State

someOwlElt :: OwlElt
someOwlElt = OwlEltSElt (OwlInfo "some elt") SEltNone

pFState_to_owlPFState :: PFState -> OwlPFState
pFState_to_owlPFState pfs@PFState {..} = OwlPFState {
  _owlPFState_owlTree = owlTree_fromSEltTree . _sPotatoFlow_sEltTree . pFState_to_sPotatoFlow $ pfs
  , _owlPFState_canvas    = _pFState_canvas
}

owlPFState_fromSElts :: [SElt] -> LBox -> OwlPFState
owlPFState_fromSElts selts lbox = pFState_to_owlPFState $ pFState_fromSElts selts lbox

owlpfstate_someValidState1 :: OwlPFState
owlpfstate_someValidState1 = pFState_to_owlPFState pfstate_someValidState1

owlpfstate_someInvalidState1 :: OwlPFState
owlpfstate_someInvalidState1 = pFState_to_owlPFState pfstate_someInvalidState1

owlpfstate_someInvalidState2 :: OwlPFState
owlpfstate_someInvalidState2 = pFState_to_owlPFState pfstate_someInvalidState2

owlpfstate_basic0 :: OwlPFState
owlpfstate_basic0 = pFState_to_owlPFState pfstate_basic0

owlpfstate_basic1 :: OwlPFState
owlpfstate_basic1 = pFState_to_owlPFState pfstate_basic1

-- | same as owlpfstate_basic1 except with folders
owlpfstate_basic2 :: OwlPFState
owlpfstate_basic2 = pFState_to_owlPFState pfstate_basic2

-- contains SElts of size 0
owlpfstate_zero :: OwlPFState
owlpfstate_zero = pFState_to_owlPFState pfstate_zero
