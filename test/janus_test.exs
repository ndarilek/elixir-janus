defmodule JanusTest do
  use ExUnit.Case
  doctest Janus

  setup do
    bypass = Bypass.open
    {:ok, bypass: bypass}
  end

  test "the truth" do
    assert 1 + 1 == 2
  end
end
