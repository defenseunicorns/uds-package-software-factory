import { Capability, a } from "pepr";

export const BumpFluxResources = new Capability({
  name: "annotate-lb",
  description:
    "Add annotation to all services of type loadbalancer so that they are provisioned with NLB instead of ELB",
  namespaces: [],
});

const { When } = BumpFluxResources;

const fluxResourcesBurstable = {
  requests: {
    cpu: "1000m",
    memory: "512Mi",
  },
  limits: {
    cpu: "3000m",
    memory: "3Gi",
  },
};

When(a.Pod)
  .IsCreated()
  .InNamespace("flux-system")
  .WithLabel("app", "source-controller")
  .Mutate(pod => {
    pod.Raw.spec.containers[0].resources = fluxResourcesBurstable;
  });

When(a.Pod)
  .IsCreated()
  .InNamespace("flux-system")
  .WithLabel("app", "helm-controller")
  .Mutate(pod => {
    pod.Raw.spec.containers[0].resources = fluxResourcesBurstable;
  });

When(a.Pod)
  .IsCreated()
  .InNamespace("flux-system")
  .WithLabel("app", "kustomize-controller")
  .Mutate(pod => {
    pod.Raw.spec.containers[0].resources = fluxResourcesBurstable;
  });
