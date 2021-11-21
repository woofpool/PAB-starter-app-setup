{-# LANGUAGE DataKinds           #-}
{-# LANGUAGE DeriveAnyClass      #-}
{-# LANGUAGE DeriveGeneric       #-}
{-# LANGUAGE DerivingStrategies  #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE GADTs               #-}
{-# LANGUAGE LambdaCase          #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications    #-}
{-# LANGUAGE TypeFamilies        #-}

module Controller (
    AppContracts(..)
    , handlers
    ) where

import Control.Monad.Freer
import Data.Aeson (FromJSON, ToJSON)
import Data.Default (Default (def))
import GHC.Generics (Generic)
import Prettyprinter

import Language.PureScript.Bridge (argonaut, equal, genericShow, mkSumType)
import Data.OpenApi.Schema qualified as OpenApi
import Playground.Types (FunctionSchema)
import Plutus.Contracts.PayToAddress qualified as Contracts.PayToAddress
import Plutus.PAB.Effects.Contract.Builtin (Builtin, BuiltinHandler (..), HasDefinitions (..), SomeBuiltin (..))
import Plutus.PAB.Effects.Contract.Builtin qualified as Builtin
import Plutus.PAB.Run.PSGenerator (HasPSTypes (..))
import Plutus.PAB.Simulator (SimulatorEffectHandlers)
import Plutus.PAB.Simulator qualified as Simulator
import Schema (FormSchema)

data AppContracts = PayToAddress
    deriving (Eq, Ord, Show, Generic)
    deriving anyclass (FromJSON, ToJSON, OpenApi.ToSchema)

instance Pretty AppContracts where
    pretty = viaShow

instance HasPSTypes AppContracts where
    psTypes = [equal . genericShow . argonaut $ mkSumType @AppContracts]

instance HasDefinitions AppContracts where
    getDefinitions = [ PayToAddress ]
    getContract = getAppContracts
    getSchema = getAppContractsSchema

getAppContractsSchema :: AppContracts -> [FunctionSchema FormSchema]
getAppContractsSchema = \case
    PayToAddress      -> Builtin.endpointsToSchemas @Contracts.PayToAddress.PayToAddressSchema

getAppContracts :: AppContracts -> SomeBuiltin
getAppContracts = \case
    PayToAddress      -> SomeBuiltin Contracts.PayToAddress.payToAddress

handlers :: SimulatorEffectHandlers (Builtin AppContracts)
handlers =
    Simulator.mkSimulatorHandlers def def
    $ interpret (contractHandler Builtin.handleBuiltin)
