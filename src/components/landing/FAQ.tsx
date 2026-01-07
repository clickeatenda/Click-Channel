import { motion } from "framer-motion";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";

const faqs = [
  {
    question: "Precisa de antena parabólica?",
    answer: "Não! O Infinity Stream funciona 100% via internet. Você só precisa de uma conexão estável de pelo menos 15 Mbps para qualidade Full HD e 25 Mbps para 4K.",
  },
  {
    question: "Funciona na minha internet?",
    answer: "Se você consegue assistir YouTube ou Netflix sem travar, vai funcionar perfeitamente. Recomendamos no mínimo 15 Mbps, mas quanto mais rápida, melhor a experiência.",
  },
  {
    question: "Tem teste grátis?",
    answer: "Sim! Oferecemos um teste gratuito de 6 horas para você conhecer a plataforma. Basta entrar em contato pelo WhatsApp e solicitar.",
  },
  {
    question: "Posso assistir em quantos dispositivos?",
    answer: "Nossos planos permitem conexão simultânea em até 2 dispositivos. Ideal para assistir na sala e no quarto ao mesmo tempo.",
  },
  {
    question: "Como funciona a liberação?",
    answer: "Após a confirmação do pagamento, seu acesso é liberado em até 15 minutos. Você recebe todas as instruções de instalação pelo WhatsApp.",
  },
  {
    question: "O serviço é legal?",
    answer: "Nosso serviço funciona através de tecnologia P2P/IPTV. Não hospedamos conteúdo, apenas facilitamos o acesso a transmissões disponíveis na internet.",
  },
];

export const FAQ = () => {
  return (
    <section id="faq" className="py-20 px-4">
      <div className="container mx-auto max-w-3xl">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6 }}
          className="text-center mb-12"
        >
          <h2 className="text-3xl md:text-4xl font-bold mb-4">
            Perguntas <span className="gradient-text">Frequentes</span>
          </h2>
          <p className="text-muted-foreground">
            Tire suas dúvidas antes de assinar.
          </p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 30 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.6, delay: 0.2 }}
        >
          <Accordion type="single" collapsible className="space-y-4">
            {faqs.map((faq, index) => (
              <AccordionItem
                key={index}
                value={`item-${index}`}
                className="glass rounded-xl px-6 border-none"
              >
                <AccordionTrigger className="text-left hover:no-underline py-5">
                  <span className="font-semibold">{faq.question}</span>
                </AccordionTrigger>
                <AccordionContent className="text-muted-foreground pb-5">
                  {faq.answer}
                </AccordionContent>
              </AccordionItem>
            ))}
          </Accordion>
        </motion.div>
      </div>
    </section>
  );
};
