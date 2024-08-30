from typing import Dict, List, Union, AsyncIterable, Optional, Any
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from multi_agent_orchestrator.types import ConversationMessage, ParticipantRole
from multi_agent_orchestrator.utils import Logger


@dataclass
class AgentProcessingResult:
    user_input: str
    agent_id: str
    agent_name: str
    user_id: str
    session_id: str
    additional_params: Dict[str, any] = field(default_factory=dict)

@dataclass
class AgentResponse:
    metadata: AgentProcessingResult
    output: Union[Any, str]
    streaming: bool


class AgentCallbacks:
    def on_llm_new_token(self, token: str) -> None:
        # Default implementation
        pass

@dataclass
class AgentOptions:
    name: str
    description: str
    model_id: Optional[str] = None
    region: Optional[str] = None
    save_chat: bool = True
    callbacks: Optional[AgentCallbacks] = None


class Agent(ABC):
    def __init__(self, options: AgentOptions):
        self.name = options.name
        self.id = self.generate_key_from_name(options.name)
        self.description = options.description
        self.save_chat = options.save_chat
        self.callbacks = options.callbacks if options.callbacks is not None else AgentCallbacks()

    @staticmethod
    def generate_key_from_name(name: str) -> str:
        import re
        # Remove special characters and replace spaces with hyphens
        key = re.sub(r'[^a-zA-Z\s-]', '', name)
        key = re.sub(r'\s+', '-', key)
        return key.lower()

    @abstractmethod
    async def process_request(
        self,
        input_text: str,
        user_id: str,
        session_id: str,
        chat_history: List[ConversationMessage],
        additional_params: Optional[Dict[str, str]] = None
    ) -> Union[ConversationMessage, AsyncIterable[any]]:
        pass

    def create_error_response(self, message: str, error: Optional[Exception] = None) -> ConversationMessage:
        error_message = "Sorry, I encountered an error while processing your request."
        if error is not None:
            error_message += f" Error details: {str(error)}"
        else:
            error_message += f" {message}"
        
        Logger.error(f"{self.name} Error: {error_message}")
        
        return ConversationMessage(
            role=ParticipantRole.ASSISTANT,
            content=[{"text": error_message}]
        )
