<script lang="ts">
  import Debugger from "./Debugger.svelte";
</script>

<svelte:boundary>
  <Debugger />

  {#snippet pending()}
    loading...
  {/snippet}
</svelte:boundary>
