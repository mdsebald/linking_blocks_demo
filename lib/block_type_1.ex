defmodule BlockType1 do
  use GenServer

  def create(block_name) do
    GenServer.start_link(__MODULE__, block_name, name: block_name)
  end

  def get(block_name, value_id) do
    GenServer.call(block_name, {:get, value_id})
  end

  def set(block_name, value_id, value) do
    GenServer.cast(block_name, {:set, value_id, value})
  end

  def execute(block_name) do
    GenServer.call(block_name, :execute)
  end

  def link(output_block_name, output_id, input_block_name, input_id) do
    GenServer.call(output_block_name, {:link, output_id, input_block_name, input_id})
  end

  def init(block_name) do
    IO.puts("Starting block: #{block_name}")
    link_registry = registry_name(block_name)
    {:ok, _pid} = Registry.start_link(name: link_registry, keys: :duplicate)
    {:ok, %{name: block_name, links: link_registry, input: nil, output: nil}}
  end

  def handle_call({:get, value_id}, _, block_state) do
    value = Map.get(block_state, value_id)
    IO.puts("Get block: #{block_name(block_state)}, value: #{value_id}, #{value}")
    {:reply, value, block_state}
  end

  def handle_call({:link, output_id, input_block_name, input_id}, _, block_state) do
    IO.puts("Linking block #{block_name(block_state)} output: #{output_id} to: input block #{input_block_name} input: #{input_id}")
    {:ok, _pid} = Registry.register(Map.get(block_state, :links), output_id, {input_block_name, input_id})
    {:reply, :ok, block_state}
  end

  def handle_call(:execute, _, block_state) do
    IO.puts("Executing block: #{block_name(block_state)}")
    input_value = Map.get(block_state, :input)
    new_block_state = Map.put(block_state, :output, input_value)
    Registry.dispatch(
      Map.get(block_state, :links),
      :output,
      fn entries -> for {_pid, {input_block_name, input_id}} <- entries, do: set(input_block_name, input_id, Map.get(new_block_state, :output)) end)
    {:reply, :ok, new_block_state}
  end

  def handle_cast({:set, value_id, value}, block_state) do
    IO.puts("Set block: #{block_name(block_state)}, value: #{value_id} to: #{value}")
    new_block_state = Map.put(block_state, :input, value)
    {:noreply, new_block_state}
  end

  defp registry_name(block_name) when is_atom(block_name) do
    String.to_atom(to_string(block_name) <> "_links")
  end

  defp block_name(block_state), do: Map.get(block_state, :name)

  def run_link_test do
    create(:block1)
    create(:block2)
    set(:block1, :input, 123)
    get(:block1, :input)
    link(:block1, :output, :block2, :input)
    get(:block2, :input)
    execute(:block1)
    get(:block1, :output)
    execute(:block2)
    get(:block2, :output)
  end
end
