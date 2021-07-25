{-# LANGUAGE LinearTypes #-}
{-# LANGUAGE UnicodeSyntax #-}

type a % b = (a,b)

type Foo a m b = a % m -> b
type Bar a m b = a %m -> b

type Baz = a ⊸ b
