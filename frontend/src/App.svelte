<script lang="ts">
  import Debugger from "./Debugger.svelte";
</script>

<svelte:boundary>
  <Debugger />

  {#snippet pending()}
    loading wasm...
  {/snippet}
</svelte:boundary>
