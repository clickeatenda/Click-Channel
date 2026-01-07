import { motion } from "framer-motion";
import { MessageCircle } from "lucide-react";

interface WhatsAppButtonProps {
  phoneNumber?: string;
}

export const WhatsAppButton = ({ phoneNumber = "" }: WhatsAppButtonProps) => {
  const whatsappUrl = phoneNumber
    ? `https://wa.me/${phoneNumber}?text=Olá! Gostaria de saber mais sobre o Infinity Stream.`
    : "#";

  return (
    <motion.a
      href={whatsappUrl}
      target="_blank"
      rel="noopener noreferrer"
      initial={{ scale: 0 }}
      animate={{ scale: 1 }}
      transition={{ delay: 1, type: "spring", stiffness: 200 }}
      whileHover={{ scale: 1.1 }}
      whileTap={{ scale: 0.95 }}
      className="fixed bottom-6 right-6 z-50 w-14 h-14 bg-[#25D366] rounded-full flex items-center justify-center shadow-lg shadow-[#25D366]/30 animate-pulse-glow"
      style={{
        boxShadow: "0 0 20px rgba(37, 211, 102, 0.4), 0 0 40px rgba(37, 211, 102, 0.2)",
      }}
    >
      <MessageCircle className="w-7 h-7 text-white" />
      <span className="sr-only">Contato via WhatsApp</span>
    </motion.a>
  );
};
