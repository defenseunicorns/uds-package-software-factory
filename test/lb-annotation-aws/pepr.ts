import { PeprModule } from "pepr";
// cfg loads your pepr configuration from package.json
import cfg from "./package.json";
import { AnnotateLB } from "./capabilities/lb-annotate";

/**
 * This is the main entrypoint for this Pepr module. It is run when the module is started.
 * This is where you register your Pepr configurations and capabilities.
 */
new PeprModule(cfg, [
  AnnotateLB,

  // Your additional capabilities go here
]);
