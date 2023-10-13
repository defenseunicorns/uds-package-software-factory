import { Capability, a } from "pepr";

export const AnnotateLB = new Capability({
  name: "annotate-lb",
  description:
    "Add annotation to all services of type loadbalancer so that they are provisioned with NLB instead of ELB",
  namespaces: [],
});

const { When } = AnnotateLB;

When(a.Service)
  .IsCreated()
  .Mutate(svc => {
    if (svc.Raw.spec.type == "LoadBalancer") {
      svc.SetAnnotation(
        "service.beta.kubernetes.io/aws-load-balancer-type",
        "nlb",
      );
    }
  });
